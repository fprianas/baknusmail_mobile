import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Hasil pertukaran data BLE antara HP dan Wemos D1 R32
class WemosBleExchangeResult {
  final String deviceId;
  final String signature;
  final String deviceName;

  const WemosBleExchangeResult({
    required this.deviceId,
    required this.signature,
    required this.deviceName,
  });
}

/// Custom Exception khusus komunikasi BLE Wemos
class WemosBleException implements Exception {
  final String message;
  final bool isBluetoothOff;
  final bool isDeviceNotFound;
  final bool isTimeout;

  const WemosBleException(
    this.message, {
    this.isBluetoothOff = false,
    this.isDeviceNotFound = false,
    this.isTimeout = false,
  });

  @override
  String toString() => message;
}

class WemosBleService {
  // UUID Standar untuk Layanan Presensi Wemos (Dapat disesuaikan di firmware ESP32)
  static const String defaultServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String defaultCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Standar alternatif (HM-10 style)
  static const String altServiceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String altCharUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";

  /// Cek apakah Bluetooth HP aktif
  Future<bool> isBluetoothEnabled() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Memulai proses scan, connect, write challenge, dan read signature dari Wemos ESP32
  Future<WemosBleExchangeResult> exchangeChallengeResponse({
    required String challengeCode,
    required String userName,
    Duration scanTimeout = const Duration(seconds: 10),
    Duration operationTimeout = const Duration(seconds: 12),
    void Function(String statusMessage)? onStatusChanged,
  }) async {
    // 1. Pastikan Bluetooth aktif
    final isEnabled = await isBluetoothEnabled();
    if (!isEnabled) {
      throw const WemosBleException(
        'Bluetooth pada smartphone Anda sedang nonaktif. Mohon aktifkan Bluetooth terlebih dahulu.',
        isBluetoothOff: true,
      );
    }

    onStatusChanged?.call('Mencari alat presensi Wemos terdekat...');

    BluetoothDevice? targetDevice;
    StreamSubscription? scanSub;

    try {
      // 2. Scan perangkat BLE yang cocok
      // Filter nama perangkat mengandung WEMOS, BAKNUS, atau PRESENSI
      final scanCompleter = Completer<BluetoothDevice?>();

      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        androidUsesFineLocation: true,
      );

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.advertisementData.advName.trim().toUpperCase();
          final platformName = r.device.platformName.trim().toUpperCase();
          final matchesName = name.contains('WEMOS') ||
              name.contains('BAKNUS') ||
              name.contains('BANUS') ||
              name.contains('RUANG GURU') ||
              name.contains('PRESENSI') ||
              platformName.contains('WEMOS') ||
              platformName.contains('BAKNUS') ||
              platformName.contains('BANUS') ||
              platformName.contains('RUANG GURU') ||
              platformName.contains('PRESENSI');

          // Cek juga Service UUID jika di-broadcast
          final matchesService = r.advertisementData.serviceUuids.any(
            (u) =>
                u.toString().toLowerCase() == defaultServiceUuid.toLowerCase() ||
                u.toString().toLowerCase() == altServiceUuid.toLowerCase(),
          );

          if (matchesName || matchesService) {
            if (!scanCompleter.isCompleted) {
              scanCompleter.complete(r.device);
            }
            break;
          }
        }
      });

      // Tunggu hingga ketemu atau scan selesai
      targetDevice = await scanCompleter.future.timeout(
        scanTimeout,
        onTimeout: () => null,
      );

      await FlutterBluePlus.stopScan();
      await scanSub.cancel();
      scanSub = null;
    } catch (e) {
      await FlutterBluePlus.stopScan();
      await scanSub?.cancel();
      if (e is WemosBleException) rethrow;
    }

    if (targetDevice == null) {
      throw const WemosBleException(
        'Alat Wemos tidak terdeteksi. Pastikan Anda berada dekat gerbang/alat',
        isDeviceNotFound: true,
      );
    }

    final String displayName = targetDevice.platformName.isNotEmpty
        ? targetDevice.platformName
        : 'Wemos Presensi';

    onStatusChanged?.call('Menghubungkan ke $displayName...');

    BluetoothCharacteristic? targetCharacteristic;

    try {
      // 3. Hubungkan ke perangkat BLE
      await targetDevice.connect(
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );

      // Request MTU yang lebih besar jika Android
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await targetDevice.requestMtu(256);
        }
      } catch (_) {}

      onStatusChanged?.call('Membaca profil BLE Wemos...');

      // 4. Discover Services & Characteristics yang TEPAT untuk Presensi Wemos
      final services = await targetDevice.discoverServices();
      for (final s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        if (sUuid == defaultServiceUuid.toLowerCase() || sUuid == altServiceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid == defaultCharUuid.toLowerCase() || cUuid == altCharUuid.toLowerCase()) {
              targetCharacteristic = c;
              break;
            }
          }
          // Jika UUID char berbeda tapi di dalam Service Wemos yang benar, pakai characteristic tersebut
          targetCharacteristic ??= s.characteristics.firstOrNull;
        }
        if (targetCharacteristic != null) break;
      }

      // Fallback kedua: jika service tidak di-broadcast, cari characteristic UUID langsung
      if (targetCharacteristic == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid == defaultCharUuid.toLowerCase() || cUuid == altCharUuid.toLowerCase()) {
              targetCharacteristic = c;
              break;
            }
          }
          if (targetCharacteristic != null) break;
        }
      }

      if (targetCharacteristic == null) {
        throw const WemosBleException(
          'Karakteristik komunikasi presensi Wemos tidak ditemukan pada perangkat ini.',
        );
      }

      onStatusChanged?.call('Mengirim token aman ke Wemos...');

      // 5. Siapkan Listener notifikasi/response sebelum mengirim challenge (Akumulatif & Tanggap Chunk)
      final responseCompleter = Completer<String>();
      String accumulated = '';
      StreamSubscription? charSub;

      if (targetCharacteristic.properties.notify || targetCharacteristic.properties.indicate) {
        try {
          await targetCharacteristic.setNotifyValue(true);
        } catch (_) {}

        charSub = targetCharacteristic.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final chunk = utf8.decode(value, allowMalformed: true);
            accumulated += chunk;
            if (accumulated.contains('DEVICE_ID:') && accumulated.contains('SIGNATURE:')) {
              if (!responseCompleter.isCompleted) {
                responseCompleter.complete(accumulated.trim());
              }
            }
          }
        });
      }

      // 6. Format pesan sesuai spesifikasi: CHALLENGE:<challenge_code>|NAME:<user_name>
      final cleanName = userName.replaceAll('|', '').replaceAll(':', '').trim();
      final outgoingPayload = 'CHALLENGE:$challengeCode|NAME:$cleanName\n';
      final bytesToSend = utf8.encode(outgoingPayload);

      await targetCharacteristic.write(
        bytesToSend,
        withoutResponse: targetCharacteristic.properties.writeWithoutResponse &&
            !targetCharacteristic.properties.write,
      );

      onStatusChanged?.call('Menunggu verifikasi signature Wemos...');

      // 7. Ambil hasil balasan (Prioritas 1: Notify, Prioritas 2: Direct Read Polling)
      String rawResponse = '';
      try {
        rawResponse = await responseCompleter.future.timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {
        // Fallback: Baca langsung dari characteristic Wemos via GATT Read
        for (int retry = 0; retry < 6; retry++) {
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            final readBytes = await targetCharacteristic.read();
            final readStr = utf8.decode(readBytes, allowMalformed: true).trim();
            if (readStr.contains('DEVICE_ID:') && readStr.contains('SIGNATURE:')) {
              rawResponse = readStr;
              break;
            }
          } catch (_) {}
        }
      }

      await charSub?.cancel();

      if (rawResponse.isEmpty) {
        throw const WemosBleException(
          'Waktu respon Wemos habis. Alat belum merespon token.',
          isTimeout: true,
        );
      }

      // 8. Parsing balasan Wemos: DEVICE_ID:<device_id>|SIGNATURE:<signature_hex>
      final parsed = _parseWemosResponse(rawResponse, fallbackDeviceName: displayName);
      return parsed;
    } on TimeoutException {
      throw const WemosBleException(
        'Koneksi Bluetooth ke Wemos terputus karena timeout.',
        isTimeout: true,
      );
    } finally {
      // Pastikan disconnect selalu terpanggil
      try {
        await targetDevice.disconnect();
      } catch (_) {}
    }
  }

  /// Helper untuk mem-parsing string balasan dari Wemos
  WemosBleExchangeResult _parseWemosResponse(
    String raw, {
    required String fallbackDeviceName,
  }) {
    String deviceId = '';
    String signature = '';

    final parts = raw.split('|');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.toUpperCase().startsWith('DEVICE_ID:')) {
        deviceId = trimmed.substring('DEVICE_ID:'.length).trim();
      } else if (trimmed.toUpperCase().startsWith('SIGNATURE:')) {
        signature = trimmed.substring('SIGNATURE:'.length).trim();
      }
    }

    if (deviceId.isEmpty || signature.isEmpty) {
      throw WemosBleException(
        'Format balasan dari alat Wemos tidak valid: "$raw"',
      );
    }

    return WemosBleExchangeResult(
      deviceId: deviceId,
      signature: signature,
      deviceName: fallbackDeviceName,
    );
  }
}
