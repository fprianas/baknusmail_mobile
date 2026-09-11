import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../data/models/attendance_model.dart';
import '../data/services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service;
  final ImagePicker _picker = ImagePicker();

  AttendanceProvider(this._service);

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isCheckingLocation = false;
  String? _errorMessage;

  AttendanceUser? _currentUser;
  AttendanceStatusResponse? _statusResponse;
  Position? _currentPosition;
  double? _distanceToSchool;
  bool _isWithinRadius = false;

  bool _isDinasLuar = false;
  String _lokasiDinasLuar = '';

  File? _lastCapturedPhoto;
  SelfieAttendanceResult? _lastResult;
  BluetoothAttendanceResult? _lastBluetoothResult;
  String? _locationErrorMessage;

  bool _hasAuthToken = false;
  String? _savedEmail;
  String? _savedPassword;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isCheckingLocation => _isCheckingLocation;
  String? get errorMessage => _errorMessage;
  bool get hasAuthToken => _hasAuthToken;

  AttendanceUser? get currentUser => _currentUser;
  AttendanceStatusResponse? get statusResponse => _statusResponse;
  Position? get currentPosition => _currentPosition;
  double? get distanceToSchool => _distanceToSchool;
  bool get isWithinRadius => _isWithinRadius;

  bool get isDinasLuar => _isDinasLuar;
  String get lokasiDinasLuar => _lokasiDinasLuar;

  File? get lastCapturedPhoto => _lastCapturedPhoto;
  SelfieAttendanceResult? get lastResult => _lastResult;
  BluetoothAttendanceResult? get lastBluetoothResult => _lastBluetoothResult;
  String? get locationErrorMessage => _locationErrorMessage;

  bool get hasFaceMaster => _statusResponse?.hasFaceMaster ?? (_hasAuthToken ? true : false);
  bool get canAttend => _statusResponse?.canAttend ?? true;
  String get presensiType => _statusResponse?.presensiType ?? 'Masuk';
  bool get hasClockedIn => _statusResponse?.hasClockedIn ?? false;
  bool get hasClockedOut => _statusResponse?.hasClockedOut ?? false;
  bool get isCompletedToday => _statusResponse?.isCompletedToday ?? false;
  AttendanceRecordItem? get recordMasuk => _statusResponse?.recordMasuk;
  AttendanceRecordItem? get recordPulang => _statusResponse?.recordPulang;

  SchoolSetting get schoolSetting =>
      _statusResponse?.schoolSetting ??
      const SchoolSetting(
        name: 'Lokasi Utama SMK Baknus 666',
        lat: -6.94148513,
        long: 107.74160564,
        radiusMeters: 200.0,
      );

  // ==================== INISIALISASI ====================

  /// Inisialisasi otomatis menggunakan sesi akun pengguna saat ini
  Future<void> initialize({
    required String userEmail,
    String? password,
    bool checkGps = false,
  }) async {
    _savedEmail = userEmail;
    if (password != null && password.isNotEmpty) {
      _savedPassword = password;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool hasToken = await _service.hasToken();

      if (!hasToken && password != null && password.isNotEmpty) {
        // 1. Coba login otomatis menggunakan full email
        try {
          _currentUser = await _service.login(username: userEmail, password: password);
          hasToken = true;
        } catch (e) {
          debugPrint('Auto-login dengan email gagal: $e. Mencoba dengan username...');
          // 2. Coba login otomatis menggunakan username pendek (contoh: frian_p)
          final shortUsername = userEmail.contains('@') ? userEmail.split('@').first : userEmail;
          if (shortUsername != userEmail) {
            try {
              _currentUser = await _service.login(username: shortUsername, password: password);
              hasToken = true;
            } catch (e2) {
              debugPrint('Auto-login dengan username pendek gagal: $e2');
            }
          }
        }
      } else if (hasToken) {
        _currentUser = await _service.getSavedUser();
      }

      _hasAuthToken = hasToken;
      // Ambil status presensi hari ini
      if (hasToken) {
        await fetchStatus();
      }

      // Cek lokasi & jarak ke sekolah hanya jika diminta (di halaman presensi)
      if (checkGps) {
        checkLocationAndDistance();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login manual jika diperlukan
  Future<bool> loginManual(String username, String password) async {
    _savedEmail = username;
    _savedPassword = password;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _service.login(username: username, password: password);
      _hasAuthToken = true;
      await fetchStatus();
      await checkLocationAndDistance();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AttendanceException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal masuk ke sistem presensi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== STATUS PRESENSI ====================

  Future<void> fetchStatus() async {
    try {
      final email = _currentUser?.email ?? _savedEmail;
      _statusResponse = await _service.getTodayStatus(userEmail: email);
      _hasAuthToken = true;
      _recalculateDistance();
      notifyListeners();
    } on AttendanceException catch (e) {
      if (e.isUnauthenticated) {
        // Coba re-login otomatis di background jika ada kredensial tersimpan
        if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
          try {
            final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
            AttendanceUser user;
            try {
              user = await _service.login(username: _savedEmail!, password: _savedPassword!);
            } catch (_) {
              user = await _service.login(username: shortU, password: _savedPassword!);
            }
            _currentUser = user;
            _hasAuthToken = true;
            _statusResponse = await _service.getTodayStatus(userEmail: user.email);
            _recalculateDistance();
            notifyListeners();
            return;
          } catch (_) {}
        }
        await _service.clearToken();
        _currentUser = null;
        _hasAuthToken = false;
      }
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchStatus: $e');
    }
  }

  // ==================== GPS GEOFENCING ====================

  Future<void> checkLocationAndDistance() async {
    _isCheckingLocation = true;
    _locationErrorMessage = null;
    notifyListeners();

    try {
      // 1. Cek Service GPS Aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationErrorMessage = 'GPS tidak aktif. Silakan aktifkan layanan lokasi di perangkat Anda.';
        _isCheckingLocation = false;
        notifyListeners();
        return;
      }

      // 2. Cek Izin Lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationErrorMessage = 'Izin akses lokasi ditolak. Aplikasi membutuhkan lokasi untuk geofencing.';
          _isCheckingLocation = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationErrorMessage = 'Izin lokasi ditolak secara permanen. Mohon izinkan lewat pengaturan HP.';
        _isCheckingLocation = false;
        notifyListeners();
        return;
      }

      // 3. Ambil posisi terakhir yang tersimpan di OS terlebih dahulu (instan, tanpa freeze)
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          _currentPosition = lastPos;
          _recalculateDistance();
          notifyListeners();
        }
      } catch (_) {}

      // 4. Perbarui dengan Posisi GPS terkini (batas waktu maksimal 4 detik agar tidak memicu ANR)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _currentPosition = position;
        _recalculateDistance();
      } catch (timeoutErr) {
        debugPrint('Geolocator.getCurrentPosition timeout/skip: $timeoutErr');
        if (_currentPosition == null) {
          _locationErrorMessage = 'Waktu pengambilan GPS habis. Silakan coba kembali.';
        }
      }
    } catch (e) {
      debugPrint('Error checkLocationAndDistance: $e');
      _locationErrorMessage = 'Gagal mendapatkan koordinat GPS: $e';
    } finally {
      _isCheckingLocation = false;
      notifyListeners();
    }
  }

  void _recalculateDistance() {
    if (_currentPosition == null) return;

    final target = schoolSetting;
    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      target.lat,
      target.long,
    );

    _distanceToSchool = meters;
    _isWithinRadius = meters <= target.radiusMeters;
  }

  // ==================== PENGATURAN DINAS LUAR ====================

  void setDinasLuar(bool value, {String? lokasi}) {
    _isDinasLuar = value;
    if (lokasi != null) {
      _lokasiDinasLuar = lokasi;
    }
    notifyListeners();
  }

  void setLokasiDinasLuar(String lokasi) {
    _lokasiDinasLuar = lokasi;
    notifyListeners();
  }

  // ==================== CAPTURE SELFIE & SUBMIT ====================

  /// Menjalankan alur capture kamera depan dan mengirim selfie ke backend CompreFace
  Future<SelfieAttendanceResult?> captureSelfieAndSubmit({bool bypassGpsCheck = false}) async {
    _errorMessage = null;

    // 1. Pastikan token otentikasi sudah tersedia
    String? token = await _service.getToken();
    if (token == null || token.isEmpty) {
      if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          token = await _service.getToken();
        } catch (_) {}
      }
    }

    if (token == null || token.isEmpty) {
      throw AttendanceException(
        message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi Anda terlebih dahulu.',
        isUnauthenticated: true,
        statusCode: 401,
      );
    }

    // 2. Pastikan posisi GPS terdeteksi (ambil jika belum ada)
    if (_currentPosition == null) {
      await checkLocationAndDistance();
    }

    // 3. Validasi GPS jika bukan dinas luar dan tidak di-bypass
    if (!_isDinasLuar && !bypassGpsCheck) {
      if (!_isWithinRadius && _distanceToSchool != null) {
        final dist = '${_distanceToSchool!.toStringAsFixed(0)}m';
        throw AttendanceException(
          message: 'Posisi Anda saat ini ($dist) berada di luar radius sekolah (${schoolSetting.radiusMeters.toStringAsFixed(0)}m). Gunakan opsi Dinas Luar jika sedang bertugas di luar sekolah.',
          isOutsideRadius: true,
          statusCode: 422,
        );
      }
    }

    if (_isDinasLuar && _lokasiDinasLuar.trim().isEmpty) {
      _lokasiDinasLuar = 'Penugasan Luar / DUDI';
    }

    // 4. Buka Kamera Depan
    final XFile? captured = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 92,
    );

    if (captured == null) {
      // Pengguna membatalkan pengambilan foto
      return null;
    }

    _isSubmitting = true;
    notifyListeners();

    // Standardisasi Foto ke Format Web:
    // 1. Putar sesuai EXIF fisik (0° tegak lurus)
    // 2. Center crop 1:1 Square (fokus wajah tengah-atas)
    // 3. Resize tepat 640x640 identik dengan standar master di server
    final File initialPhoto = await _processSelfieImage(File(captured.path), mirror: false);
    _lastCapturedPhoto = initialPhoto;

    final double lat = _currentPosition?.latitude ?? schoolSetting.lat;
    final double long = _currentPosition?.longitude ?? schoolSetting.long;

    try {
      final result = await _service.submitSelfie(
        photo: initialPhoto,
        lat: lat,
        long: long,
        isDinasLuar: _isDinasLuar,
        lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
      );

      _lastResult = result;
      // Muat ulang status terbaru
      await fetchStatus();

      return result;
    } on AttendanceException catch (e) {
      // Auto-Fallback Cerdas: Jika ditolak karena "Wajah Tidak Cocok",
      // besar kemungkinan kamera depan HP melakukan auto-mirror (pembalikan horizontal).
      // Kita langsung coba otomatis kirimkan versi mirrored (flipHorizontal) dari foto yang sama!
      if (e.isFaceMismatch) {
        debugPrint('CompreFace AI: Wajah tidak cocok pada percobaan pertama. Mencoba otomatis versi mirror...');
        try {
          final mirrorPhoto = await _processSelfieImage(File(captured.path), mirror: true);
          final mirrorResult = await _service.submitSelfie(
            photo: mirrorPhoto,
            lat: lat,
            long: long,
            isDinasLuar: _isDinasLuar,
            lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
          );
          _lastCapturedPhoto = mirrorPhoto;
          _lastResult = mirrorResult;
          await fetchStatus();
          return mirrorResult;
        } catch (mirrorError) {
          debugPrint('CompreFace AI: Percobaan versi mirror juga gagal: $mirrorError');
        }
      }

      if (e.isUnauthenticated && _savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          // Re-login otomatis di background dan coba kirim ulang sekali
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          final retryResult = await _service.submitSelfie(
            photo: _lastCapturedPhoto!,
            lat: lat,
            long: long,
            isDinasLuar: _isDinasLuar,
            lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
          );
          _lastResult = retryResult;
          await fetchStatus();
          return retryResult;
        } catch (_) {}
      }
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== PRE-PROCESSING FOTO KE STANDAR 640x640 ====================

  /// Memproses foto selfie kamera HP agar memenuhi standar CompreFace di server:
  /// 1. Memutar orientasi fisik sesuai EXIF (0 derajat tegak lurus).
  /// 2. Memotong ke rasio persegi 1:1 (fokus pada wajah di area tengah-atas).
  /// 3. Mengubah ukuran tepat ke 640 x 640 pixel (identik dengan master database).
  /// 4. Opsi mirror horizontal (jika kamera depan HP membalik foto).
  Future<File> _processSelfieImage(File rawFile, {bool mirror = false}) async {
    try {
      final bytes = await rawFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return rawFile;

      // 1. Bake EXIF Orientation agar pixel benar-benar tegak 0 derajat
      decoded = img.bakeOrientation(decoded);

      // 2. Balik horizontal jika mode mirror aktif
      if (mirror) {
        decoded = img.flipHorizontal(decoded);
      }

      // 3. Center Crop 1:1 Square (fokus wajah di area tengah-atas)
      final minDim = decoded.width < decoded.height ? decoded.width : decoded.height;
      final xOffset = (decoded.width - minDim) ~/ 2;
      final int yOffset = decoded.height > decoded.width
          ? ((decoded.height - minDim) * 0.25).round().clamp(0, decoded.height - minDim)
          : 0;

      final cropped = img.copyCrop(
        decoded,
        x: xOffset,
        y: yOffset,
        width: minDim,
        height: minDim,
      );

      // 4. Resize tepat 640x640 (standar CompreFace web BaknusAttend)
      final resized = img.copyResize(
        cropped,
        width: 640,
        height: 640,
        interpolation: img.Interpolation.cubic,
      );

      // 5. Simpan sebagai file JPEG bersih tanpa anomali EXIF
      final jpgBytes = img.encodeJpg(resized, quality: 90);
      final processedPath = rawFile.path.replaceAll('.jpg', mirror ? '_mirror_640.jpg' : '_crop_640.jpg');
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(jpgBytes);
      return processedFile;
    } catch (e) {
      debugPrint('Error _processSelfieImage: $e');
      return rawFile;
    }
  }

  // ==================== REGISTER MASTER FACE ====================

  /// Mendaftarkan foto wajah master pertama kali jika has_face_master == false
  Future<bool> registerMasterFace() async {
    _errorMessage = null;

    final XFile? captured = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 92,
    );

    if (captured == null) return false;

    _isSubmitting = true;
    notifyListeners();

    try {
      final processed = await _processSelfieImage(File(captured.path), mirror: false);
      await _service.registerMasterFace(photo: processed);
      // Refresh status agar has_face_master menjadi true
      await fetchStatus();
      return true;
    } on AttendanceException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== PRESENSI TAP KARTU NFC ====================

  /// Mengirim data presensi mandiri via Tap Kartu NFC (Mifare / e-KTP / Kartu Pelajar)
  Future<CardTapAttendanceResult> submitCardTap({
    required String rfidUid,
    bool bypassGpsCheck = false,
  }) async {
    _errorMessage = null;

    // 1. Pastikan token otentikasi sudah tersedia
    String? token = await _service.getToken();
    if (token == null || token.isEmpty) {
      if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          token = await _service.getToken();
        } catch (_) {}
      }
    }

    if (token == null || token.isEmpty) {
      throw AttendanceException(
        message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi terlebih dahulu.',
        isUnauthenticated: true,
        statusCode: 401,
      );
    }

    // 2. Pastikan posisi GPS terdeteksi
    if (_currentPosition == null) {
      await checkLocationAndDistance();
    }

    // 3. Validasi GPS jika bukan dinas luar dan tidak di-bypass
    if (!_isDinasLuar && !bypassGpsCheck) {
      if (!_isWithinRadius && _distanceToSchool != null) {
        final dist = '${_distanceToSchool!.toStringAsFixed(0)}m';
        throw AttendanceException(
          message: 'Posisi Anda saat ini ($dist) berada di luar radius sekolah (${schoolSetting.radiusMeters.toStringAsFixed(0)}m). Gunakan opsi Dinas Luar jika sedang bertugas di luar sekolah.',
          isOutsideRadius: true,
          statusCode: 422,
        );
      }
    }

    final double lat = _currentPosition?.latitude ?? schoolSetting.lat;
    final double long = _currentPosition?.longitude ?? schoolSetting.long;

    _isSubmitting = true;
    notifyListeners();

    try {
      final result = await _service.submitCardTap(
        rfidUid: rfidUid,
        lat: lat,
        long: long,
        isDinasLuar: _isDinasLuar,
        lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
      );

      // Muat ulang status kehadiran
      await fetchStatus();
      return result;
    } on AttendanceException catch (e) {
      if (e.isUnauthenticated && _savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          final retryResult = await _service.submitCardTap(
            rfidUid: rfidUid,
            lat: lat,
            long: long,
            isDinasLuar: _isDinasLuar,
            lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
          );
          await fetchStatus();
          return retryResult;
        } catch (_) {}
      }
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== PRESENSI BLUETOOTH BLE OFFLINE WEMOS ====================

  /// Meminta challenge code acak dari server untuk presensi Bluetooth
  Future<BluetoothChallengeResponse> getBluetoothChallenge() async {
    _errorMessage = null;

    // Pastikan token otentikasi sudah tersedia
    String? token = await _service.getToken();
    if (token == null || token.isEmpty) {
      if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
        } catch (_) {}
      }
    }

    try {
      return await _service.getBluetoothChallenge();
    } on AttendanceException catch (e) {
      _errorMessage = e.message;
      rethrow;
    }
  }

  /// Mengirim hasil verifikasi presensi Bluetooth ke server
  Future<BluetoothAttendanceResult> submitBluetoothAttendance({
    required String deviceId,
    required String challengeCode,
    required String signature,
    bool bypassGpsCheck = false,
  }) async {
    _errorMessage = null;

    // 1. Pastikan token otentikasi sudah tersedia
    String? token = await _service.getToken();
    if (token == null || token.isEmpty) {
      if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          token = await _service.getToken();
        } catch (_) {}
      }
    }

    if (token == null || token.isEmpty) {
      throw AttendanceException(
        message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi terlebih dahulu.',
        isUnauthenticated: true,
        statusCode: 401,
      );
    }

    // 2. Pastikan posisi GPS terdeteksi
    if (_currentPosition == null) {
      await checkLocationAndDistance();
    }

    // 3. Validasi GPS jika bukan dinas luar dan tidak di-bypass
    if (!_isDinasLuar && !bypassGpsCheck) {
      if (!_isWithinRadius && _distanceToSchool != null) {
        final dist = '${_distanceToSchool!.toStringAsFixed(0)}m';
        throw AttendanceException(
          message: 'Posisi Anda saat ini ($dist) berada di luar radius sekolah (${schoolSetting.radiusMeters.toStringAsFixed(0)}m). Gunakan opsi Dinas Luar jika sedang bertugas di luar sekolah.',
          isOutsideRadius: true,
          statusCode: 422,
        );
      }
    }

    final double lat = _currentPosition?.latitude ?? schoolSetting.lat;
    final double long = _currentPosition?.longitude ?? schoolSetting.long;

    _isSubmitting = true;
    notifyListeners();

    try {
      final result = await _service.verifyBluetoothAttendance(
        deviceId: deviceId,
        challengeCode: challengeCode,
        signature: signature,
        lat: lat,
        long: long,
        isDinasLuar: _isDinasLuar,
        lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
      );

      _lastBluetoothResult = result;
      // Muat ulang status kehadiran hari ini
      await fetchStatus();
      return result;
    } on AttendanceException catch (e) {
      if (e.isUnauthenticated && _savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
        try {
          final shortU = _savedEmail!.contains('@') ? _savedEmail!.split('@').first : _savedEmail!;
          try {
            await _service.login(username: _savedEmail!, password: _savedPassword!);
          } catch (_) {
            await _service.login(username: shortU, password: _savedPassword!);
          }
          final retryResult = await _service.verifyBluetoothAttendance(
            deviceId: deviceId,
            challengeCode: challengeCode,
            signature: signature,
            lat: lat,
            long: long,
            isDinasLuar: _isDinasLuar,
            lokasiDinasLuar: _isDinasLuar ? _lokasiDinasLuar.trim() : null,
          );
          _lastBluetoothResult = retryResult;
          await fetchStatus();
          return retryResult;
        } catch (_) {}
      }
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
