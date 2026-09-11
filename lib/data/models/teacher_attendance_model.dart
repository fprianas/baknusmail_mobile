import 'dart:convert';

/// Model untuk staf / guru yang telah melakukan presensi masuk hari ini
class TeacherAttendance {
  final String nip;
  final String nama;
  final String role; // 'Guru', 'TU', 'Admin'
  final String jabatan;
  final String waktuMasuk;
  final String metode; // 'Selfie GPS', 'NFC Tap', 'Bluetooth'
  final String status; // 'Tepat Waktu', 'Terlambat', 'Dinas Luar'
  final String? fotoUrl; // BISA NULL jika presensi via NFC/Bluetooth

  TeacherAttendance({
    required this.nip,
    required this.nama,
    required this.role,
    required this.jabatan,
    required this.waktuMasuk,
    required this.metode,
    required this.status,
    this.fotoUrl,
  });

  factory TeacherAttendance.fromJson(Map<String, dynamic> json) {
    return TeacherAttendance(
      nip: json['nip']?.toString() ?? json['nipy']?.toString() ?? '-',
      nama: json['nama']?.toString() ?? json['name']?.toString() ?? 'Guru',
      role: json['role']?.toString() ?? 'Guru',
      jabatan: json['jabatan'] ?? json['unit'] ?? json['department']?.toString() ?? 'Tenaga Pendidik',
      waktuMasuk: json['waktu_masuk']?.toString() ?? json['waktu']?.toString() ?? json['time']?.toString() ?? '-',
      metode: json['metode']?.toString() ?? json['method']?.toString() ?? 'Selfie GPS',
      status: json['status']?.toString() ?? json['keterangan']?.toString() ?? 'Tepat Waktu',
      fotoUrl: (json['foto_url'] != null && json['foto_url'].toString().trim().isNotEmpty)
          ? json['foto_url'].toString().trim()
          : ((json['photo_url'] != null && json['photo_url'].toString().trim().isNotEmpty)
              ? json['photo_url'].toString().trim()
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nip': nip,
      'nama': nama,
      'role': role,
      'jabatan': jabatan,
      'waktu_masuk': waktuMasuk,
      'metode': metode,
      'status': status,
      if (fotoUrl != null) 'foto_url': fotoUrl,
    };
  }
}

// Alias untuk backwards-compatibility
typedef HadirTeacher = TeacherAttendance;

/// Model rangkuman kehadiran Guru & Tenaga Kependidikan hari ini dari GET /api/presence/teachers-today
class TeacherAttendanceSummary {
  final String status;
  final String? message;
  final String date;
  final int totalHadir;
  final List<TeacherAttendance> data;

  TeacherAttendanceSummary({
    required this.status,
    this.message,
    required this.date,
    required this.totalHadir,
    required this.data,
  });

  factory TeacherAttendanceSummary.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] ?? json['teachers'] ?? json['hadir'] ?? [];
    List<TeacherAttendance> list = [];
    if (rawList is List) {
      list = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => TeacherAttendance.fromJson(e))
          .toList();
    }

    final int total = json['total_hadir'] is num
        ? (json['total_hadir'] as num).toInt()
        : list.length;

    return TeacherAttendanceSummary(
      status: (json['status'] ?? 'success').toString(),
      message: json['message']?.toString(),
      date: (json['date'] ?? json['tanggal'] ?? '').toString(),
      totalHadir: total,
      data: list,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (message != null) 'message': message,
      'date': date,
      'total_hadir': totalHadir,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }

  String toRawJson() => jsonEncode(toJson());

  static TeacherAttendanceSummary? fromRawJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TeacherAttendanceSummary.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
