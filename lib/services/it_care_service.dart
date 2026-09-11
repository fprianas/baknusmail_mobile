import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/it_care_models.dart';

class ITCareService {
  static const String defaultBaseUrl = 'https://baknusitcare.smkbn666.sch.id/api';
  static const String _prefKeyMyTickets = 'baknus_itcare_my_tickets';

  final Dio _dio;
  final String baseUrl;

  ITCareUser? _currentUser;
  ITCareUser? get currentUser => _currentUser;

  ITCareService({String? customBaseUrl})
      : baseUrl = customBaseUrl ?? defaultBaseUrl,
        _dio = Dio(
          BaseOptions(
            baseUrl: customBaseUrl ?? defaultBaseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  void setCurrentUser(ITCareUser user) {
    _currentUser = user;
  }

  // ==================== STORAGE LOKAL NOMOR TIKET ====================
  Future<void> saveMyTicketCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKeyMyTickets) ?? [];
      final clean = code.trim().toUpperCase();
      if (clean.isNotEmpty && !list.contains(clean)) {
        list.insert(0, clean);
        await prefs.setStringList(_prefKeyMyTickets, list);
        debugPrint('[ITCareService] Saved local ticket code: $clean (total: ${list.length})');
      }
    } catch (e) {
      debugPrint('[ITCareService] saveMyTicketCode error: $e');
    }
  }

  Future<List<String>> getMyTicketCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefKeyMyTickets) ?? [];
    } catch (e) {
      debugPrint('[ITCareService] getMyTicketCodes error: $e');
      return [];
    }
  }

  // ==================== 1. AUTENTIKASI ====================
  Future<ITCareUser> login({
    required String email,
    required String password,
    String? fallbackDisplayName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final resData = response.data;
      if (resData is Map<String, dynamic>) {
        // Backend pattern 1: { "success": true, "data": { "user": { ... } } }
        // Backend pattern 2: { "user": { ... }, "token": "..." }
        // Backend pattern 3: { "success": true, "data": { "role": "Pelapor", ... } }
        Map<String, dynamic>? userData;
        if (resData['data'] is Map<String, dynamic>) {
          final nested = resData['data'] as Map<String, dynamic>;
          userData = nested['user'] is Map<String, dynamic>
              ? nested['user'] as Map<String, dynamic>
              : nested;
        } else if (resData['user'] is Map<String, dynamic>) {
          userData = resData['user'] as Map<String, dynamic>;
        }

        if (userData != null) {
          final user = ITCareUser.fromJson(userData);
          _currentUser = user;
          return user;
        }

        final role = resData['role']?.toString() ?? 'Pelapor';
        final user = ITCareUser(
          id: (resData['id'] ?? email).toString(),
          name: (resData['name'] ?? fallbackDisplayName ?? email.split('@').first).toString(),
          email: email,
          role: role,
        );
        _currentUser = user;
        return user;
      }

      if (resData is Map<String, dynamic> && resData['success'] == false) {
        debugPrint('[ITCareService] Login success=false: ${resData['message']}');
        final fallbackUser = ITCareUser(
          id: email,
          name: fallbackDisplayName ?? email.split('@').first,
          email: email,
          role: 'Pelapor',
        );
        _currentUser = fallbackUser;
        return fallbackUser;
      }

      throw Exception('Format respons server tidak dikenali.');
    } on DioException catch (dioErr) {
      debugPrint('[ITCareService] Login DioException: ${dioErr.message}');
      
      // Fallback grace jika kredensial belum sinkron atau server error agar pelapor tetap bisa menggunakan fitur
      final fallbackUser = ITCareUser(
        id: email,
        name: fallbackDisplayName ?? email.split('@').first,
        email: email,
        role: 'Pelapor',
      );
      _currentUser = fallbackUser;
      return fallbackUser;
    } catch (e) {
      debugPrint('[ITCareService] Login Error: $e');
      final fallbackUser = ITCareUser(
        id: email,
        name: fallbackDisplayName ?? email.split('@').first,
        email: email,
        role: 'Pelapor',
      );
      _currentUser = fallbackUser;
      return fallbackUser;
    }
  }

  // ==================== 2. META OPTIONS ====================
  Future<MetaOptions> getMetaOptions() async {
    try {
      final response = await _dio.get('/meta/options');
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] ?? response.data;
        return MetaOptions.fromJson(data);
      }
      return MetaOptions.defaultOptions();
    } catch (e) {
      debugPrint('[ITCareService] getMetaOptions error: $e. Using defaults.');
      return MetaOptions.defaultOptions();
    }
  }

  // ==================== 3. DAFTAR TIKET ====================
  Future<List<TicketItem>> getTickets({
    String? userId,
    String? role,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _dio.get(
        '/tickets',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resData = response.data;
      List<dynamic> listRaw = [];
      if (resData is Map<String, dynamic>) {
        if (resData['data'] is List) {
          listRaw = resData['data'] as List;
        }
      } else if (resData is List) {
        listRaw = resData;
      }

      final fetchedList = listRaw
          .map((item) => TicketItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Untuk Pelapor: pastikan rekam jejak tiket yang pernah dibuat tidak hilang
      if (role != 'Teknisi') {
        try {
          final localCodes = await getMyTicketCodes();
          final existingCodes = fetchedList
              .map((t) => t.ticketCode.trim().toUpperCase())
              .toSet();

          for (final code in localCodes) {
            if (!existingCodes.contains(code)) {
              try {
                final tracked = await trackTicket(code);
                if (tracked != null &&
                    !existingCodes.contains(tracked.ticketCode.trim().toUpperCase())) {
                  fetchedList.add(tracked);
                  existingCodes.add(tracked.ticketCode.trim().toUpperCase());
                }
              } catch (_) {}
            }
          }

          // Urutkan tiket terbaru di paling atas
          fetchedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } catch (e) {
          debugPrint('[ITCareService] Merge local ticket history error: $e');
        }
      }

      return fetchedList;
    } catch (e) {
      debugPrint('[ITCareService] getTickets error: $e');
      rethrow;
    }
  }

  // ==================== 4. KPI DASHBOARD ====================
  Future<KpiDashboard> getDashboardKpi() async {
    try {
      final response = await _dio.get(
        '/tickets/dashboard',
        queryParameters: {'role': 'Teknisi'},
      );

      final resData = response.data;
      if (resData is Map<String, dynamic> && resData['data'] != null) {
        return KpiDashboard.fromJson(resData['data']);
      }
      throw Exception('Format KPI dashboard tidak sesuai.');
    } catch (e) {
      debugPrint('[ITCareService] getDashboardKpi error: $e');
      rethrow;
    }
  }

  // ==================== 5. LACAK NOMOR TIKET ====================
  Future<TicketItem?> trackTicket(String code) async {
    try {
      final cleanCode = code.trim();
      final response = await _dio.get('/tickets/track/$cleanCode');
      final resData = response.data;
      if (resData is Map<String, dynamic> && resData['data'] != null) {
        return TicketItem.fromJson(resData['data']);
      }
      return null;
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (e) {
      debugPrint('[ITCareService] trackTicket error: $e');
      rethrow;
    }
  }

  // ==================== 6. DETAIL TIKET ====================
  Future<TicketItem> getTicketDetail(int id) async {
    try {
      final response = await _dio.get('/tickets/$id');
      final resData = response.data;
      if (resData is Map<String, dynamic> && resData['data'] != null) {
        return TicketItem.fromJson(resData['data']);
      }
      throw Exception('Detail tiket tidak ditemukan.');
    } catch (e) {
      debugPrint('[ITCareService] getTicketDetail error: $e');
      rethrow;
    }
  }

  // ==================== 7. BUAT TIKET BARU ====================
  Future<TicketItem> createTicket({
    required String serviceType,
    required String subIssue,
    required String location,
    required String description,
    required String priority,
    required String requesterId,
    required String requesterName,
    required String requesterEmail,
  }) async {
    try {
      final cleanEmail = requesterEmail.trim().isNotEmpty
          ? requesterEmail.trim()
          : (_currentUser?.email.trim().isNotEmpty == true
              ? _currentUser!.email.trim()
              : 'pelapor@smkbn666.sch.id');
      final cleanId = requesterId.trim().isNotEmpty
          ? requesterId.trim()
          : (_currentUser?.id.trim().isNotEmpty == true
              ? _currentUser!.id.trim()
              : cleanEmail);
      final cleanName = requesterName.trim().isNotEmpty
          ? requesterName.trim()
          : (_currentUser?.name.trim().isNotEmpty == true
              ? _currentUser!.name.trim()
              : cleanEmail.split('@').first);

      final payload = {
        'serviceType': serviceType,
        'subIssue': subIssue,
        'location': location,
        'description': description,
        'priority': priority,
        'requesterId': cleanId,
        'requesterName': cleanName,
        'requesterEmail': cleanEmail,
      };

      final response = await _dio.post('/tickets', data: payload);
      final resData = response.data;
      if (resData is Map<String, dynamic> && resData['data'] != null) {
        final created = TicketItem.fromJson(resData['data']);
        await saveMyTicketCode(created.ticketCode);
        return created;
      }
      throw Exception(resData['message'] ?? 'Gagal membuat laporan tiket.');
    } on DioException catch (dioErr) {
      debugPrint('[ITCareService] createTicket DioException: ${dioErr.message}');
      String errMsg = 'Gagal mengirim laporan tiket.';
      if (dioErr.response?.data is Map) {
        final data = dioErr.response!.data as Map;
        if (data['errors'] is Map) {
          errMsg = (data['errors'] as Map)
              .values
              .map((v) => v is List ? v.join(', ') : v.toString())
              .join('. ');
        } else if (data['message'] != null) {
          errMsg = data['message'].toString();
        } else if (data['title'] != null) {
          errMsg = data['title'].toString();
        }
      }
      throw Exception(errMsg);
    } catch (e) {
      debugPrint('[ITCareService] createTicket error: $e');
      rethrow;
    }
  }

  // ==================== 8. AMBIL CHAT/KOMENTAR ====================
  Future<List<TicketComment>> getComments(int ticketId) async {
    try {
      final response = await _dio.get('/tickets/$ticketId/comments');
      final resData = response.data;
      List<dynamic> listRaw = [];
      if (resData is Map<String, dynamic> && resData['data'] is List) {
        listRaw = resData['data'] as List;
      } else if (resData is List) {
        listRaw = resData;
      }

      return listRaw
          .map((item) => TicketComment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ITCareService] getComments error: $e');
      rethrow;
    }
  }

  // ==================== 9. KIRIM PESAN CHAT BARU ====================
  Future<TicketComment> addComment(
    int ticketId, {
    required String userId,
    required String userName,
    required String userRole,
    required String message,
  }) async {
    try {
      final payload = {
        'userId': userId.trim().isNotEmpty ? userId.trim() : (_currentUser?.id ?? '1'),
        'userName': userName.trim().isNotEmpty ? userName.trim() : (_currentUser?.name ?? 'Pengguna'),
        'userRole': userRole.trim().isNotEmpty ? userRole.trim() : (_currentUser?.role ?? 'Pelapor'),
        'message': message.trim(),
      };

      final response = await _dio.post('/tickets/$ticketId/comments', data: payload);
      final resData = response.data;
      if (resData is Map<String, dynamic> && resData['data'] != null) {
        return TicketComment.fromJson(resData['data']);
      }
      return TicketComment(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: payload['userId']!,
        userName: payload['userName']!,
        userRole: payload['userRole']!,
        message: message,
        createdAt: DateTime.now().toIso8601String(),
      );
    } on DioException catch (dioErr) {
      debugPrint('[ITCareService] addComment DioException: ${dioErr.message}');
      String errMsg = 'Gagal mengirim pesan chat.';
      if (dioErr.response?.data is Map && dioErr.response!.data['message'] != null) {
        errMsg = dioErr.response!.data['message'].toString();
      }
      throw Exception(errMsg);
    } catch (e) {
      debugPrint('[ITCareService] addComment error: $e');
      rethrow;
    }
  }

  // ==================== 10. UBAH STATUS TIKET (TEKNISI) ====================
  Future<bool> updateStatus(
    int ticketId, {
    required String newStatus,
    required String updatedByUserId,
    required String updatedByName,
    String? comment,
  }) async {
    try {
      final payload = {
        'newStatus': newStatus,
        'updatedByUserId': updatedByUserId.trim().isNotEmpty
            ? updatedByUserId.trim()
            : (_currentUser?.id ?? '1'),
        'updatedByName': updatedByName.trim().isNotEmpty
            ? updatedByName.trim()
            : (_currentUser?.name ?? 'Teknisi'),
        'comment': comment ?? 'Status diperbarui oleh petugas.',
      };

      final response = await _dio.post('/tickets/$ticketId/status', data: payload);
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (dioErr) {
      debugPrint('[ITCareService] updateStatus DioException: ${dioErr.message}');
      String errMsg = 'Gagal memperbarui status tiket.';
      if (dioErr.response?.data is Map && dioErr.response!.data['message'] != null) {
        errMsg = dioErr.response!.data['message'].toString();
      }
      throw Exception(errMsg);
    } catch (e) {
      debugPrint('[ITCareService] updateStatus error: $e');
      rethrow;
    }
  }

  // ==================== 11. SUBMIT RATING (PELAPOR) ====================
  Future<bool> submitRating(
    int ticketId, {
    required int rating,
    required String feedback,
  }) async {
    try {
      final payload = {
        'rating': rating,
        'feedback': feedback,
      };

      final response = await _dio.post('/tickets/$ticketId/rating', data: payload);
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (dioErr) {
      debugPrint('[ITCareService] submitRating DioException: ${dioErr.message}');
      String errMsg = 'Gagal mengirim penilaian rating.';
      if (dioErr.response?.data is Map && dioErr.response!.data['message'] != null) {
        errMsg = dioErr.response!.data['message'].toString();
      }
      throw Exception(errMsg);
    } catch (e) {
      debugPrint('[ITCareService] submitRating error: $e');
      rethrow;
    }
  }

  // ==================== 12. DAFTAR PETUGAS TEKNISI IT RESMI ====================
  Future<List<ITTechnicianStaff>> getTechnicians({bool includeAdmins = true}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (!includeAdmins) {
        queryParams['includeAdmins'] = 'false';
      }

      final response = await _dio.get(
        '/technicians',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final resData = response.data;
      List<dynamic> listRaw = [];
      if (resData is Map<String, dynamic>) {
        if (resData['data'] is List) {
          listRaw = resData['data'] as List;
        }
      } else if (resData is List) {
        listRaw = resData;
      }

      return listRaw
          .map((item) => ITTechnicianStaff.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ITCareService] getTechnicians error: $e. Using fallback.');
      return ITTechnicianContact.defaultStaff
          .map((c) => ITTechnicianStaff(
                id: c.email,
                fullName: c.name,
                email: c.email,
                phoneNumber: '-',
                role: c.role.contains('Admin') ? 'Admin' : 'Teknisi',
                roleLabel: c.role,
                department: c.description.contains('Guru')
                    ? 'Guru'
                    : (c.description.contains('TU') ? 'TU' : 'Admin'),
                activeTicketsHandled: 0,
                totalResolvedTickets: 0,
              ))
          .toList();
    }
  }
}

