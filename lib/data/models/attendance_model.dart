class SchoolSetting {
  final String name;
  final double lat;
  final double long;
  final double radiusMeters;

  const SchoolSetting({
    this.name = 'Lokasi Utama SMK Baknus 666',
    required this.lat,
    required this.long,
    required this.radiusMeters,
  });

  factory SchoolSetting.fromJson(Map<String, dynamic> json) {
    // Sinkronkan nama dan koordinat sesuai konfigurasi server
    final rawName = json['nama_lokasi'] ?? json['name'] ?? json['location_name'] ?? json['nama'];
    final rawLat = json['latitude'] ?? json['lat'] ?? json['lokasi_lat'];
    final rawLong = json['longitude'] ?? json['long'] ?? json['lng'] ?? json['lokasi_long'];
    final rawRadius = json['radius'] ?? json['radius_meters'] ?? json['radius_meter'] ?? json['radius_toleransi'];

    return SchoolSetting(
      name: rawName?.toString() ?? 'Lokasi Utama SMK Baknus 666',
      lat: (rawLat is num)
          ? rawLat.toDouble()
          : double.tryParse(rawLat?.toString() ?? '') ?? -6.94148513, // Sesuai Server: -6.94148513
      long: (rawLong is num)
          ? rawLong.toDouble()
          : double.tryParse(rawLong?.toString() ?? '') ?? 107.74160564, // Sesuai Server: 107.74160564
      radiusMeters: (rawRadius is num)
          ? rawRadius.toDouble()
          : double.tryParse(rawRadius?.toString() ?? '') ?? 200.0, // Sesuai Server: 200m
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'long': long,
        'radius_meters': radiusMeters,
      };
}

class AttendanceRecordItem {
  final String? type; // "Masuk", "Pulang"
  final String? waktu;
  final String? photoUrl;
  final double? similarity;
  final bool isDinasLuar;
  final String? lokasiDinasLuar;

  const AttendanceRecordItem({
    this.type,
    this.waktu,
    this.photoUrl,
    this.similarity,
    this.isDinasLuar = false,
    this.lokasiDinasLuar,
  });

  factory AttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordItem(
      type: json['type'] ?? json['status'] ?? json['presensi_type'],
      waktu: json['waktu'] ?? json['time'] ?? json['waktu_tap'],
      photoUrl: json['photo_url'] ?? json['watermark_photo_url'] ?? json['photo'],
      similarity: (json['similarity'] is num)
          ? (json['similarity'] as num).toDouble()
          : double.tryParse(json['similarity']?.toString() ?? ''),
      isDinasLuar: json['is_dinas_luar'] == 1 || json['is_dinas_luar'] == true || json['is_dinas_luar'] == '1',
      lokasiDinasLuar: json['lokasi_dinas_luar']?.toString(),
    );
  }
}

class AttendanceStatusResponse {
  final String presensiType; // "Masuk" | "Pulang" | "Selesai" | "Libur" | "Izin"
  final bool canAttend;
  final String? reason;
  final bool hasFaceMaster;
  final SchoolSetting schoolSetting;
  final List<AttendanceRecordItem> todayRecords;

  const AttendanceStatusResponse({
    required this.presensiType,
    required this.canAttend,
    this.reason,
    required this.hasFaceMaster,
    required this.schoolSetting,
    this.todayRecords = const [],
  });

  AttendanceRecordItem? get recordMasuk {
    for (final r in todayRecords) {
      if (r.type?.toLowerCase().contains('masuk') == true) return r;
    }
    return null;
  }

  AttendanceRecordItem? get recordPulang {
    for (final r in todayRecords) {
      if (r.type?.toLowerCase().contains('pulang') == true) return r;
    }
    return null;
  }

  bool get hasClockedIn =>
      recordMasuk != null ||
      presensiType.toLowerCase().contains('pulang') ||
      presensiType.toLowerCase().contains('selesai');

  bool get hasClockedOut =>
      recordPulang != null ||
      presensiType.toLowerCase().contains('selesai');

  bool get isCompletedToday =>
      (hasClockedIn && hasClockedOut) ||
      presensiType.toLowerCase().contains('selesai');

  factory AttendanceStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;

    final recordsRaw = data['today_records'] ?? data['records'] ?? data['presensi_hari_ini'];
    List<AttendanceRecordItem> records = [];
    if (recordsRaw is List) {
      records = recordsRaw
          .whereType<Map<String, dynamic>>()
          .map((r) => AttendanceRecordItem.fromJson(r))
          .toList();
    }

    // Ekstraksi data setting sekolah yang fleksibel dari berbagai format JSON Laravel
    Map<String, dynamic> settingRaw = {};
    if (data['school_setting'] is Map<String, dynamic>) {
      settingRaw = data['school_setting'] as Map<String, dynamic>;
    } else if (data['school_settings'] is Map<String, dynamic>) {
      settingRaw = data['school_settings'] as Map<String, dynamic>;
    } else if (data['setting'] is Map<String, dynamic>) {
      settingRaw = data['setting'] as Map<String, dynamic>;
    } else if (data['location'] is Map<String, dynamic>) {
      settingRaw = data['location'] as Map<String, dynamic>;
    } else if (data['school'] is Map<String, dynamic>) {
      settingRaw = data['school'] as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      settingRaw = data;
    }

    // Helper boolean fleksibel (mendukung bool, int, string "1"/"true")
    bool parseBool(dynamic val, {bool defaultValue = false}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      if (val is num) return val == 1;
      final str = val.toString().trim().toLowerCase();
      return str == '1' || str == 'true' || str == 'yes';
    }

    // Cek has_face_master di berbagai kemungkinan key Laravel
    final rawHasFace = data['has_face_master'] ??
        data['has_face'] ??
        data['face_registered'] ??
        data['is_face_registered'] ??
        data['has_master'] ??
        (data['user'] is Map ? (data['user']['has_face_master'] ?? data['user']['has_face'] ?? data['user']['face_master']) : null);

    final rawCanAttend = data['can_attend'] ?? data['allowed'] ?? true;

    return AttendanceStatusResponse(
      presensiType: data['presensi_type']?.toString() ?? data['type']?.toString() ?? 'Masuk',
      canAttend: parseBool(rawCanAttend, defaultValue: true),
      reason: data['reason']?.toString(),
      hasFaceMaster: parseBool(rawHasFace, defaultValue: true), // Jika sudah sinkron, default ke true
      schoolSetting: SchoolSetting.fromJson(settingRaw),
      todayRecords: records,
    );
  }
}

class SelfieAttendanceResult {
  final bool isSuccess;
  final String presensiType;
  final String? waktu;
  final double? similarity;
  final String? photoWatermarkUrl;
  final String? message;

  const SelfieAttendanceResult({
    required this.isSuccess,
    required this.presensiType,
    this.waktu,
    this.similarity,
    this.photoWatermarkUrl,
    this.message,
  });

  factory SelfieAttendanceResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;

    return SelfieAttendanceResult(
      isSuccess: json['status'] == 'success' || json['success'] == true || data['presensi_type'] != null,
      presensiType: data['presensi_type'] ?? data['type'] ?? '',
      waktu: data['waktu'] ?? data['time'] ?? data['jam'],
      similarity: (data['similarity'] is num)
          ? (data['similarity'] as num).toDouble()
          : double.tryParse(data['similarity']?.toString() ?? ''),
      photoWatermarkUrl: data['photo_watermark_url'] ?? data['watermark_url'] ?? data['photo_url'],
      message: json['message']?.toString() ?? data['message']?.toString(),
    );
  }
}

class AttendanceUser {
  final String? id;
  final String name;
  final String username;
  final String email;
  final String role;
  final bool hasFaceMaster;
  final String? masterPhotoUrl;
  final String? token;

  const AttendanceUser({
    this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    this.hasFaceMaster = false,
    this.masterPhotoUrl,
    this.token,
  });

  factory AttendanceUser.fromJson(Map<String, dynamic> json, {String? token}) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json);

    return AttendanceUser(
      id: userMap['id']?.toString(),
      name: userMap['name']?.toString() ?? userMap['displayName']?.toString() ?? '',
      username: userMap['username']?.toString() ?? '',
      email: userMap['email']?.toString() ?? '',
      role: userMap['role']?.toString() ?? 'Siswa',
      hasFaceMaster: userMap['has_face_master'] == true || userMap['has_face_master'] == 1,
      masterPhotoUrl: userMap['master_photo_url']?.toString() ?? userMap['photo_url']?.toString(),
      token: token ?? json['token']?.toString() ?? json['access_token']?.toString(),
    );
  }
}

class CardTapAttendanceResult {
  final bool isSuccess;
  final String message;
  final int? id;
  final String tipe; // "Masuk" / "Pulang"
  final String statusKehadiran; // "Hadir"
  final String? rfidUid;
  final bool isNewlyLinked;
  final String? waktu;
  final String? jam;

  const CardTapAttendanceResult({
    required this.isSuccess,
    required this.message,
    this.id,
    required this.tipe,
    required this.statusKehadiran,
    this.rfidUid,
    this.isNewlyLinked = false,
    this.waktu,
    this.jam,
  });

  factory CardTapAttendanceResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return CardTapAttendanceResult(
      isSuccess: json['status'] == 'success' || json['success'] == true,
      message: json['message']?.toString() ?? 'Presensi Tap Kartu Berhasil!',
      id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? ''),
      tipe: data['tipe']?.toString() ?? data['type']?.toString() ?? 'Masuk',
      statusKehadiran: data['status_kehadiran']?.toString() ?? 'Hadir',
      rfidUid: data['rfid_uid']?.toString(),
      isNewlyLinked: data['is_newly_linked'] == true || data['is_newly_linked'] == 1,
      waktu: data['waktu']?.toString(),
      jam: data['jam']?.toString(),
    );
  }
}

/// Model respon challenge token Bluetooth dari Server
class BluetoothChallengeResponse {
  final bool isSuccess;
  final String challengeCode;
  final int expiresIn;
  final String userName;
  final String tipe;

  const BluetoothChallengeResponse({
    required this.isSuccess,
    required this.challengeCode,
    required this.expiresIn,
    required this.userName,
    required this.tipe,
  });

  factory BluetoothChallengeResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return BluetoothChallengeResponse(
      isSuccess: json['status'] == 'success' || json['success'] == true,
      challengeCode: data['challenge_code']?.toString() ?? json['challenge_code']?.toString() ?? '',
      expiresIn: int.tryParse(data['expires_in']?.toString() ?? json['expires_in']?.toString() ?? '60') ?? 60,
      userName: data['user_name']?.toString() ?? json['user_name']?.toString() ?? 'Pengguna',
      tipe: data['tipe']?.toString() ?? json['tipe']?.toString() ?? 'Masuk',
    );
  }
}

/// Model hasil presensi Bluetooth Wemos BLE setelah diverifikasi server
class BluetoothAttendanceResult {
  final bool isSuccess;
  final String message;
  final int? id;
  final String tipe; // "Masuk" / "Pulang"
  final String statusKehadiran; // "Hadir"
  final String? deviceId; // "WEMOS_GERBANG_01"
  final String? deviceName; // "Gerbang Depan"
  final String? waktu;
  final String? jam;

  const BluetoothAttendanceResult({
    required this.isSuccess,
    required this.message,
    this.id,
    required this.tipe,
    required this.statusKehadiran,
    this.deviceId,
    this.deviceName,
    this.waktu,
    this.jam,
  });

  factory BluetoothAttendanceResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return BluetoothAttendanceResult(
      isSuccess: json['status'] == 'success' || json['success'] == true,
      message: json['message']?.toString() ?? 'Presensi Bluetooth Berhasil!',
      id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? ''),
      tipe: data['tipe']?.toString() ?? data['type']?.toString() ?? 'Masuk',
      statusKehadiran: data['status_kehadiran']?.toString() ?? 'Hadir',
      deviceId: data['device_id']?.toString(),
      deviceName: data['device_name']?.toString() ?? data['device_id']?.toString(),
      waktu: data['waktu']?.toString(),
      jam: data['jam']?.toString(),
    );
  }
}
