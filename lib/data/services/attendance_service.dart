import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_model.dart';
import '../models/baknus_service_models.dart';
import '../models/class_attendance_model.dart';
import '../models/teacher_attendance_model.dart';

/// Exception khusus untuk penanganan respon API BaknusAttend
class AttendanceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isFaceMismatch;
  final bool isOutsideRadius;
  final bool isRateLimit;
  final bool isUnauthenticated;
  final bool isCompleted;
  final bool isRouteNotFound;
  final dynamic rawData;

  AttendanceException({
    required this.message,
    this.statusCode,
    this.isFaceMismatch = false,
    this.isOutsideRadius = false,
    this.isRateLimit = false,
    this.isUnauthenticated = false,
    this.isCompleted = false,
    this.isRouteNotFound = false,
    this.rawData,
  });

  @override
  String toString() => message;
}

class AttendanceService {
  static const String _defaultApiUrl = 'https://baknusattend.smkbn666.sch.id/api';
  static const String _tokenKey = 'baknus_attend_bearer_token';
  static const String _userKey = 'baknus_attend_user_data';

  // In-memory cache agar token selalu tersedia instan tanpa delay IPC/Keystore
  static String? _cachedToken;
  static AttendanceUser? _cachedUser;

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  // Legacy dashboard URL & Key untuk rekap kalender bulanan
  static const String _legacyBaseUrl = 'https://baknusattend.smkbn666.sch.id/api/user-stats';
  static const String _legacyApiKey = 'baknus_secret_dashboard_key_2026';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final String baseUrl;

  AttendanceService({
    String? baseUrl,
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : baseUrl = baseUrl ?? _defaultApiUrl,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: _androidOptions,
              iOptions: _iosOptions,
            ),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? _defaultApiUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Sisipkan Bearer token otomatis jika belum ada di header
          if (!options.headers.containsKey('Authorization')) {
            final token = await getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
      ),
    );
  }

  // ==================== TOKEN & STORAGE MULTI-TIER ====================

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(
        key: _tokenKey,
        value: token,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (e) {
      debugPrint('Error saving token to secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('Error saving token to shared prefs: $e');
    }
  }

  Future<String?> getToken() async {
    // 1. Cek dari RAM cache (tercepat & paling andal)
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    // 2. Cek dari FlutterSecureStorage
    try {
      final token = await _storage.read(
        key: _tokenKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('Error reading secure token: $e');
    }
    // 3. Fallback ke SharedPreferences jika Android Keystore mengalami kendala
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('Error reading prefs token: $e');
    }
    return null;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _cachedUser = null;
    try {
      await _storage.delete(key: _tokenKey, aOptions: _androidOptions, iOptions: _iosOptions);
      await _storage.delete(key: _userKey, aOptions: _androidOptions, iOptions: _iosOptions);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveSavedUser(AttendanceUser user) async {
    _cachedUser = user;
    try {
      final map = {
        'id': user.id,
        'name': user.name,
        'username': user.username,
        'email': user.email,
        'role': user.role,
        'has_face_master': user.hasFaceMaster,
        'master_photo_url': user.masterPhotoUrl,
      };
      final jsonStr = jsonEncode(map);
      await _storage.write(key: _userKey, value: jsonStr, aOptions: _androidOptions, iOptions: _iosOptions);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  Future<AttendanceUser?> getSavedUser() async {
    if (_cachedUser != null) return _cachedUser;
    try {
      String? raw = await _storage.read(key: _userKey, aOptions: _androidOptions, iOptions: _iosOptions);
      if (raw == null) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_userKey);
      }
      if (raw != null) {
        _cachedUser = AttendanceUser.fromJson(jsonDecode(raw));
        return _cachedUser;
      }
    } catch (_) {}
    return null;
  }

  // ==================== 1. LOGIN PENGGUNA ====================

  /// POST /auth/login
  /// Mengirim `{"username": "NIS/NIPY/Email", "password": "password"}`
  /// Mengembalikan objek AttendanceUser dan menyimpan Bearer Token ke secure storage.
  Future<AttendanceUser> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username.trim(),
          'email': username.trim(),
          'password': password,
        },
      );

      final data = response.data;
      String? token;
      if (data is Map) {
        token = data['token']?.toString() ??
            data['access_token']?.toString() ??
            (data['data'] is Map ? (data['data']['token']?.toString() ?? data['data']['access_token']?.toString()) : null) ??
            (data['authorisation'] is Map ? data['authorisation']['token']?.toString() : null) ??
            (data['authorization'] is Map ? data['authorization']['token']?.toString() : null);
      }

      if (token != null && token.isNotEmpty) {
        await saveToken(token);
      }

      final user = AttendanceUser.fromJson(data, token: token);
      await saveSavedUser(user);
      return user;
    } on DioException catch (e) {
      throw _handleDioError(e, 'Login Gagal');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Terjadi kesalahan sistem login: $e');
    }
  }

  // ==================== 2. CEK STATUS PRESENSI & LOKASI SEKOLAH ====================

  /// GET /presence/status
  /// Mengambil status presensi hari ini, setting koordinat sekolah, dan riwayat tap.
  /// Memiliki fallback cerdas ke /api/user-stats jika middleware backend mengalami kendala.
  Future<AttendanceStatusResponse> getTodayStatus({String? userEmail}) async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/presence/status',
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return AttendanceStatusResponse.fromJson(response.data);
    } catch (e) {
      debugPrint('GET /presence/status error: $e. Memeriksa fallback /api/user-stats...');
      // Fallback cerdas: Ambil status presensi dari /api/user-stats jika token middleware backend bermasalah
      final email = userEmail ?? (await getSavedUser())?.email;
      if (email != null && email.isNotEmpty) {
        try {
          final stats = await getUserAttendance(email: email);
          if (stats != null && stats['detail_kehadiran'] is List) {
            final now = DateTime.now();
            final todayStr =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final details = (stats['detail_kehadiran'] as List)
                .whereType<Map<String, dynamic>>()
                .toList();

            List<AttendanceRecordItem> todayRecords = [];
            bool hasIn = false;
            bool hasOut = false;

            for (final d in details) {
              final waktu = d['waktu_tap']?.toString() ?? '';
              if (waktu.startsWith(todayStr)) {
                final ket = d['keterangan']?.toString() ?? '';
                final isMasuk = ket.toLowerCase().contains('masuk');
                final isPulang = ket.toLowerCase().contains('pulang');
                final timeOnly =
                    waktu.split(' ').length > 1 ? waktu.split(' ')[1] : waktu;

                if (isMasuk) hasIn = true;
                if (isPulang) hasOut = true;

                todayRecords.add(
                  AttendanceRecordItem(
                    type: isMasuk ? 'Masuk' : (isPulang ? 'Pulang' : 'Hadir'),
                    waktu: timeOnly,
                    photoUrl: d['photo_url'],
                    isDinasLuar:
                        d['is_dinas_luar'] == 1 || d['is_dinas_luar'] == true,
                    lokasiDinasLuar: d['lokasi_dinas_luar']?.toString(),
                  ),
                );
              }
            }

            final savedUser = await getSavedUser();
            final hasMaster = savedUser?.hasFaceMaster ?? true;

            String presensiType = 'Masuk';
            if (hasIn && hasOut) {
              presensiType = 'Selesai';
            } else if (hasIn) {
              presensiType = 'Pulang';
            }

            return AttendanceStatusResponse(
              presensiType: presensiType,
              canAttend: !hasOut,
              hasFaceMaster: hasMaster,
              schoolSetting: const SchoolSetting(
                name: 'Lokasi Utama SMK Baknus 666',
                lat: -6.94148513,
                long: 107.74160564,
                radiusMeters: 200.0,
              ),
              todayRecords: todayRecords,
            );
          }
        } catch (fallbackError) {
          debugPrint('Fallback /api/user-stats error: $fallbackError');
        }
      }

      if (e is DioException) {
        throw _handleDioError(e, 'Gagal memuat status presensi');
      }
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Kesalahan memuat status: $e');
    }
  }

  // ==================== 3. KIRIM ABSEN SELFIE (MAIN ENDPOINT) ====================

  /// POST /presence/selfie
  /// Multipart: photo, lat, long, is_dinas_luar, lokasi_dinas_luar
  Future<SelfieAttendanceResult> submitSelfie({
    required File photo,
    required double lat,
    required double long,
    bool isDinasLuar = false,
    String? lokasiDinasLuar,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw AttendanceException(
          message: 'Sesi presensi belum terhubung atau token kadaluarsa. Silakan hubungkan akun presensi.',
          isUnauthenticated: true,
          statusCode: 401,
        );
      }

      final fileName = photo.path.split(Platform.pathSeparator).last;

      final formDataMap = <String, dynamic>{
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: fileName.isNotEmpty ? fileName : 'selfie.jpg',
        ),
        'lat': lat.toString(),
        'long': long.toString(),
        'latitude': lat.toString(),
        'longitude': long.toString(),
        'is_dinas_luar': isDinasLuar ? '1' : '0',
        'threshold': '0.90',
        'similarity_threshold': '0.90',
        'min_similarity': '90',
      };

      if (isDinasLuar && lokasiDinasLuar != null && lokasiDinasLuar.isNotEmpty) {
        formDataMap['lokasi_dinas_luar'] = lokasiDinasLuar;
      }

      final formData = FormData.fromMap(formDataMap);

      // Jangan menambahkan 'contentType: multipart/form-data' di Options karena Dio
      // harus menghasilkan boundary multipart secara otomatis agar PHP/Laravel dapat mem-parsingnya.
      final response = await _dio.post(
        '/presence/selfie',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return SelfieAttendanceResult.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Presensi Selfie Gagal');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Gagal mengirim presensi selfie: $e');
    }
  }

  // ==================== 4. DAFTAR WAJAH MASTER ====================

  /// POST /presence/register-face
  /// Multipart: photo (File wajah jelas tanpa masker)
  Future<Map<String, dynamic>> registerMasterFace({
    required File photo,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw AttendanceException(
          message: 'Sesi presensi belum terhubung. Silakan hubungkan akun terlebih dahulu.',
          isUnauthenticated: true,
          statusCode: 401,
        );
      }

      final fileName = photo.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: fileName.isNotEmpty ? fileName : 'master_face.jpg',
        ),
      });

      final response = await _dio.post(
        '/presence/register-face',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'Pendaftaran Wajah Master Gagal');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Gagal mendaftarkan wajah: $e');
    }
  }

  // ==================== 5. PRESENSI TAP KARTU NFC ====================

  /// POST /presence/card-tap
  /// Mengirim UID kartu RFID/NFC dan koordinat GPS untuk presensi mandiri
  Future<CardTapAttendanceResult> submitCardTap({
    required String rfidUid,
    required double lat,
    required double long,
    bool isDinasLuar = false,
    String? lokasiDinasLuar,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw AttendanceException(
          message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi terlebih dahulu.',
          isUnauthenticated: true,
          statusCode: 401,
        );
      }

      final payload = <String, dynamic>{
        'rfid_uid': rfidUid.trim().toUpperCase(),
        'lat': lat,
        'long': long,
        'latitude': lat,
        'longitude': long,
        'is_dinas_luar': isDinasLuar ? 1 : 0,
      };

      if (isDinasLuar && lokasiDinasLuar != null && lokasiDinasLuar.isNotEmpty) {
        payload['lokasi_dinas_luar'] = lokasiDinasLuar;
      }

      final response = await _dio.post(
        '/presence/card-tap',
        data: payload,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return CardTapAttendanceResult.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Presensi Tap Kartu Gagal');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Gagal mengirim presensi tap kartu: $e');
    }
  }

  /// Memastikan URL selalu terarah tepat ke base URL lengkap (termasuk prefix /api)
  String _buildUrl(String path) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  // ==================== PRESENSI BLUETOOTH BLE OFFLINE WEMOS ====================

  /// Meminta challenge code acak dari server untuk presensi Bluetooth
  /// GET /api/presence/bluetooth/challenge
  Future<BluetoothChallengeResponse> getBluetoothChallenge() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw AttendanceException(
          message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi terlebih dahulu.',
          isUnauthenticated: true,
          statusCode: 401,
        );
      }

      final targetUrl = _buildUrl('/presence/bluetooth/challenge');
      final response = await _dio.get(
        targetUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return BluetoothChallengeResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Gagal Meminta Token Bluetooth');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Gagal meminta token tantangan Bluetooth: $e');
    }
  }

  /// Memverifikasi signature dari Wemos dan mencatat presensi Bluetooth ke server
  /// POST /api/presence/bluetooth/verify
  Future<BluetoothAttendanceResult> verifyBluetoothAttendance({
    required String deviceId,
    required String challengeCode,
    required String signature,
    required double lat,
    required double long,
    bool isDinasLuar = false,
    String? lokasiDinasLuar,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw AttendanceException(
        message: 'Sesi presensi belum terhubung. Silakan hubungkan akun presensi terlebih dahulu.',
        isUnauthenticated: true,
        statusCode: 401,
      );
    }

    try {
      final payload = <String, dynamic>{
        'device_id': deviceId.trim(),
        'challenge_code': challengeCode.trim(),
        'signature': signature.trim(),
        'lat': lat,
        'long': long,
        'latitude': lat,
        'longitude': long,
        'is_dinas_luar': isDinasLuar ? 1 : 0,
      };

      if (isDinasLuar && lokasiDinasLuar != null && lokasiDinasLuar.isNotEmpty) {
        payload['lokasi_dinas_luar'] = lokasiDinasLuar;
      }

      final targetUrl = _buildUrl('/presence/bluetooth/verify');
      final response = await _dio.post(
        targetUrl,
        data: payload,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return BluetoothAttendanceResult.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Verifikasi Presensi Bluetooth Gagal');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Gagal memverifikasi presensi Bluetooth: $e');
    }
  }

  // ==================== ERROR HANDLING TERPADU ====================

  AttendanceException _handleDioError(DioException e, String fallbackTitle) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String message = '$fallbackTitle: ${e.message}';
    bool isFaceMismatch = false;
    bool isOutsideRadius = false;
    bool isRateLimit = (status == 429);
    bool isUnauth = (status == 401);

    if (data is Map<String, dynamic>) {
      final rawMsg = data['message'] ?? data['error'] ?? data['reason'];
      if (rawMsg != null) {
        message = rawMsg.toString();
      }

      // Deteksi status 422
      if (status == 422) {
        final lowerMsg = message.toLowerCase();
        final errors = data['errors'];
        String fullErrorsStr = '';
        if (errors is Map) {
          fullErrorsStr = errors.values.join(' ').toLowerCase();
        }

        // Cek indikator wajah tidak cocok (CompreFace AI < 90%)
        if (lowerMsg.contains('wajah') ||
            lowerMsg.contains('face') ||
            lowerMsg.contains('cocok') ||
            lowerMsg.contains('similarity') ||
            lowerMsg.contains('tidak dikenali') ||
            fullErrorsStr.contains('wajah') ||
            fullErrorsStr.contains('face') ||
            fullErrorsStr.contains('similarity')) {
          isFaceMismatch = true;
          if (rawMsg != null && rawMsg.toString().trim().isNotEmpty) {
            message = rawMsg.toString();
          } else {
            message = 'Wajah tidak cocok, pastikan pencahayaan cukup dan hadapkan wajah lurus ke kamera.';
          }
        }

        // Cek indikator di luar radius GPS
        if (lowerMsg.contains('radius') ||
            lowerMsg.contains('jarak') ||
            lowerMsg.contains('lokasi') ||
            lowerMsg.contains('luar lingkungan') ||
            fullErrorsStr.contains('radius') ||
            fullErrorsStr.contains('jarak')) {
          isOutsideRadius = true;
          if (!message.contains('radius')) {
            message = 'Posisi GPS Anda berada di luar radius lingkungan sekolah.';
          }
        }
      }
    }

    if (isRateLimit) {
      message = 'Terlalu banyak percobaan presensi dalam waktu singkat. Mohon tunggu beberapa saat sebelum mencoba kembali.';
    } else if (isUnauth) {
      if (data is Map && (data['message'] != null || data['error'] != null)) {
        message = (data['message'] ?? data['error']).toString();
      } else {
        message = 'Sesi presensi telah berakhir atau tidak valid. Silakan hubungkan ulang akun Anda.';
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Koneksi ke server presensi terputus (Timeout). Periksa koneksi internet Anda.';
    }

    // Deteksi jika presensi hari ini sudah selesai (Masuk & Pulang)
    final lowerCheck = message.toLowerCase();
    bool isCompleted = false;
    if (lowerCheck.contains('sudah menyelesaikan absensi') ||
        lowerCheck.contains('sudah presensi hari ini') ||
        (lowerCheck.contains('selesai') && lowerCheck.contains('hari ini'))) {
      isCompleted = true;
    }

    // Penanganan khusus 404 jika route endpoint belum terdaftar di backend
    bool isRouteNotFound = (status == 404);
    if (status == 404) {
      if (e.requestOptions.path.contains('card-tap') || lowerCheck.contains('card-tap')) {
        message = 'Fitur Tap Kartu NFC belum aktif di server: Route POST /api/presence/card-tap belum didaftarkan di routes/api.php Laravel.';
      } else {
        message = 'Layanan API tidak ditemukan di server (Error 404).';
      }
    }

    return AttendanceException(
      message: message,
      statusCode: status,
      isFaceMismatch: isFaceMismatch,
      isOutsideRadius: isOutsideRadius,
      isRateLimit: isRateLimit,
      isUnauthenticated: isUnauth,
      isCompleted: isCompleted,
      isRouteNotFound: isRouteNotFound,
      rawData: data,
    );
  }

  // ==================== LEGACY METHOD UNTUK REKAP KALENDER ====================

  /// Mengambil data statistik & rincian absensi bulanan pengguna (kompatibilitas kalender)
  static Future<Map<String, dynamic>?> getUserAttendance({
    required String email,
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = {
        'email': email.trim().toLowerCase(),
        if (month != null) 'month': month.toString(),
        if (year != null) 'year': year.toString(),
      };
      final uri = Uri.parse(_legacyBaseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _legacyApiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == 'success' && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getUserAttendance: $e');
      return null;
    }
  }

  /// Helper untuk mengambil data langsung sebagai model BaknusAttendData
  static Future<BaknusAttendData?> getUserAttendanceModel({
    required String email,
    int? month,
    int? year,
  }) async {
    final data = await getUserAttendance(email: email, month: month, year: year);
    if (data != null) {
      return BaknusAttendData.fromJson(data);
    }
    return null;
  }

  // ==================== ENDPOINTS BOT PRESENSI KELAS (GURU & TU) ====================

  /// GET /api/presence/classes
  /// Mengambil daftar rombel/kelas aktif untuk pilihan bot chat @presensi.
  /// Hanya dapat diakses oleh akun Guru, TU, atau Admin.
  Future<List<ClassItem>> getClasses() async {
    final token = await getToken();
    final targetUrl = _buildUrl('/presence/classes');

    try {
      final response = await _dio.get(
        targetUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      List rawList = [];
      if (data is Map) {
        if (data['data'] is List) {
          rawList = data['data'];
        } else if (data['classes'] is List) {
          rawList = data['classes'];
        }
      } else if (data is List) {
        rawList = data;
      }

      if (rawList.isNotEmpty) {
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => ClassItem.fromJson(e))
            .toList();
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 403) {
        throw AttendanceException(
          message: 'Akses ditolak: Data kehadiran kelas hanya dapat diakses oleh Guru dan Staf TU.',
          statusCode: 403,
        );
      }
      debugPrint('GET /presence/classes error: $e');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      debugPrint('GET /presence/classes general error: $e');
    }

    // Fallback daftar kelas standar SMK Bakti Nusantara 666 jika server offline/belum terhubung
    return [
      ClassItem(id: 'X-PPLG-1', code: 'X-PPLG-1', name: 'X PPLG 1', tingkat: 10, jurusan: 'PPLG'),
      ClassItem(id: 'X-PPLG-2', code: 'X-PPLG-2', name: 'X PPLG 2', tingkat: 10, jurusan: 'PPLG'),
      ClassItem(id: 'XI-PPLG-1', code: 'XI-PPLG-1', name: 'XI PPLG 1', tingkat: 11, jurusan: 'PPLG'),
      ClassItem(id: 'XI-PPLG-2', code: 'XI-PPLG-2', name: 'XI PPLG 2', tingkat: 11, jurusan: 'PPLG'),
      ClassItem(id: 'XII-PPLG-1', code: 'XII-PPLG-1', name: 'XII PPLG 1', tingkat: 12, jurusan: 'PPLG'),
      ClassItem(id: 'X-TKJ-1', code: 'X-TKJ-1', name: 'X TKJ 1', tingkat: 10, jurusan: 'TKJ'),
      ClassItem(id: 'XI-TKJ-1', code: 'XI-TKJ-1', name: 'XI TKJ 1', tingkat: 11, jurusan: 'TKJ'),
      ClassItem(id: 'XII-TKJ-1', code: 'XII-TKJ-1', name: 'XII TKJ 1', tingkat: 12, jurusan: 'TKJ'),
      ClassItem(id: 'X-DKV-1', code: 'X-DKV-1', name: 'X DKV 1', tingkat: 10, jurusan: 'DKV'),
      ClassItem(id: 'XI-DKV-1', code: 'XI-DKV-1', name: 'XI DKV 1', tingkat: 11, jurusan: 'DKV'),
      ClassItem(id: 'XII-DKV-1', code: 'XII-DKV-1', name: 'XII DKV 1', tingkat: 12, jurusan: 'DKV'),
      ClassItem(id: 'X-ANIMASI-1', code: 'X-ANIMASI-1', name: 'X ANIMASI 1', tingkat: 10, jurusan: 'ANIMASI'),
      ClassItem(id: 'XI-ANIMASI-1', code: 'XI-ANIMASI-1', name: 'XI ANIMASI 1', tingkat: 11, jurusan: 'ANIMASI'),
      ClassItem(id: 'XII-ANIMASI-1', code: 'XII-ANIMASI-1', name: 'XII ANIMASI 1', tingkat: 12, jurusan: 'ANIMASI'),
      ClassItem(id: 'X-BCF-1', code: 'X-BCF-1', name: 'X BCF 1', tingkat: 10, jurusan: 'BCF'),
      ClassItem(id: 'XI-BCF-1', code: 'XI-BCF-1', name: 'XI BCF 1', tingkat: 11, jurusan: 'BCF'),
      ClassItem(id: 'XII-BCF-1', code: 'XII-BCF-1', name: 'XII BCF 1', tingkat: 12, jurusan: 'BCF'),
    ];
  }

  /// GET /api/presence/today-by-class
  /// Mengambil rekap kehadiran siswa hari ini untuk satu kelas tertentu.
  /// Parameter [classId] bisa berupa ID numerik (1) atau nama/kode kelas ('X-PPLG-1' / 'X PPLG 1').
  Future<ClassAttendanceSummary> getTodayClassAttendance({
    required dynamic classId,
    String? date,
  }) async {
    final token = await getToken();
    final targetUrl = _buildUrl('/presence/today-by-class');

    final queryParams = <String, dynamic>{
      'class_id': classId.toString(),
      if (date != null && date.isNotEmpty) 'date': date,
    };

    try {
      final response = await _dio.get(
        targetUrl,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['status'] == 'success' || data['data'] != null) {
          final payload = data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
          return ClassAttendanceSummary.fromJson(payload);
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errData = e.response?.data;
      String errMsg = 'Gagal mengambil data kehadiran kelas.';

      if (errData is Map && errData['message'] != null) {
        errMsg = errData['message'].toString();
      }

      if (statusCode == 403) {
        throw AttendanceException(
          message: errMsg.isNotEmpty ? errMsg : 'Akses ditolak: Data kehadiran kelas hanya dapat diakses oleh Guru dan Staf TU.',
          statusCode: 403,
        );
      }
      throw _handleDioError(e, 'Gagal memuat rekap kehadiran kelas');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Kesalahan sistem: $e');
    }

    throw AttendanceException(message: 'Format data dari server tidak sesuai.');
  }

  // ==================== ENDPOINT BOT KEHADIRAN GURU & TU (@HADIR) ====================

  /// GET /api/presence/teachers-today
  /// Mengambil daftar Guru & Tenaga Kependidikan (TU) yang SUDAH hadir hari ini.
  /// Hanya dapat diakses oleh akun dengan role Guru, TU, atau Admin.
  Future<TeacherAttendanceSummary> getTodayTeachersAttendance({
    String? date,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw AttendanceException(
        message: '⚠️ Sesi presensi Anda belum terhubung atau telah berakhir. Silakan login ulang.',
        statusCode: 401,
        isUnauthenticated: true,
      );
    }

    final targetUrl = _buildUrl('/presence/teachers-today');
    final queryParams = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
    };

    try {
      final response = await _dio.get(
        targetUrl,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return TeacherAttendanceSummary.fromJson(data);
      }
      throw AttendanceException(
        message: 'Format data respon dari server tidak sesuai.',
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errData = e.response?.data;
      String errMsg = 'Gagal mengambil data kehadiran.';

      if (errData is Map && errData['message'] != null) {
        errMsg = errData['message'].toString();
      }

      // 403 Forbidden: Hak akses khusus Guru & TU
      if (statusCode == 403) {
        throw AttendanceException(
          message: '⚠️ Akses ditolak: Fitur @hadir hanya dapat diakses oleh Guru dan Staf TU.',
          statusCode: 403,
        );
      } else if (statusCode == 401) {
        throw AttendanceException(
          message: '⚠️ Sesi presensi Anda telah berakhir. Silakan login ulang.',
          statusCode: 401,
          isUnauthenticated: true,
        );
      } else if (statusCode == 500) {
        throw AttendanceException(
          message: 'Terjadi kendala pada server backend (HTTP 500: $errMsg). Silakan periksa log backend server.',
          statusCode: 500,
        );
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw AttendanceException(
          message: 'Gagal mengambil data kehadiran. Silakan periksa koneksi internet Anda.',
        );
      }

      throw AttendanceException(
        message: errMsg,
        statusCode: statusCode,
      );
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceException(message: 'Kesalahan sistem: $e');
    }
  }
}
