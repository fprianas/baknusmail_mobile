import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final bool isNotEnrolled;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.isNotEnrolled = false,
  });
}

class SecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _pinSalt = 'baknus_sec_salt_v1_';

  /// Cek apakah perangkat mendukung biometrik atau kredensial perangkat
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('SecurityService.isDeviceSupported error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah sensor biometrik tersedia dan dapat digunakan
  Future<bool> canCheckBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException catch (e) {
      debugPrint('SecurityService.canCheckBiometrics error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan daftar tipe biometrik yang didukung HP (Fingerprint, Face, Iris, dll)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('SecurityService.getAvailableBiometrics error: $e');
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Label nama sensor yang lebih ramah pengguna
  Future<String> getBiometricLabel() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Pemindai Wajah (Face ID)';
    } else if (biometrics.contains(BiometricType.fingerprint) || biometrics.contains(BiometricType.strong)) {
      return 'Sidik Jari (Fingerprint)';
    } else if (biometrics.isNotEmpty) {
      return 'Biometrik Perangkat';
    }
    return 'Biometrik / Kunci HP';
  }

  /// Meminta otentikasi biometrik bawaan HP dengan hasil mendalam
  Future<BiometricAuthResult> authenticateBiometrics({
    String reason = 'Gunakan biometrik untuk membuka BaknusMail',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return const BiometricAuthResult(
          success: false,
          errorMessage: 'HP tidak mendukung sensor biometrik atau kunci perangkat.',
        );
      }

      final canCheck = await canCheckBiometrics();
      final biometrics = await getAvailableBiometrics();
      if (!canCheck && biometrics.isEmpty) {
        return const BiometricAuthResult(
          success: false,
          errorMessage: 'Sidik jari atau wajah belum didaftarkan di Pengaturan HP Anda. Silakan tambahkan di Pengaturan HP -> Keamanan.',
          isNotEnrolled: true,
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      return BiometricAuthResult(
        success: authenticated,
        errorMessage: authenticated ? null : 'Verifikasi biometrik dibatalkan.',
      );
    } on PlatformException catch (e) {
      debugPrint('SecurityService.authenticateBiometrics PlatformException: ${e.code} - ${e.message}');
      String message = 'Verifikasi biometrik gagal.';
      bool notEnrolled = false;

      switch (e.code) {
        case 'NotEnrolled':
          message = 'Belum ada sidik jari atau wajah yang didaftarkan di HP Anda. Silakan daftarkan di menu Pengaturan (Settings) HP Anda terlebih dahulu.';
          notEnrolled = true;
          break;
        case 'LockedOut':
          message = 'Sensor biometrik terkunci sementara karena beberapa kali salah. Coba lagi beberapa saat.';
          break;
        case 'PermanentlyLockedOut':
          message = 'Sensor terkunci permanen. Buka kunci HP Anda dengan PIN/Pola HP terlebih dahulu.';
          break;
        case 'PasscodeNotSet':
          message = 'Kunci layar HP (PIN/Pola) belum diatur di HP ini.';
          break;
        case 'NotAvailable':
          message = 'Sensor biometrik tidak aktif atau tidak tersedia saat ini.';
          break;
        default:
          message = e.message ?? 'Verifikasi biometrik dibatalkan atau gagal.';
      }

      return BiometricAuthResult(
        success: false,
        errorMessage: message,
        isNotEnrolled: notEnrolled,
      );
    } catch (e) {
      debugPrint('SecurityService.authenticateBiometrics unexpected error: $e');
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Gagal memicu sensor biometrik: $e',
      );
    }
  }

  /// Hash 6-digit PIN menggunakan SHA-256 dan Salt
  String hashPin(String pin) {
    final bytes = utf8.encode('$_pinSalt$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifikasi PIN yang diinput dengan hash yang tersimpan
  bool verifyPin(String inputPin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    final hashedInput = hashPin(inputPin);
    return hashedInput == storedHash;
  }
}
