import 'dart:convert';

/// Model untuk item kelas yang didapatkan dari GET /api/presence/classes
class ClassItem {
  final dynamic id;
  final String code;
  final String name;
  final int? tingkat;
  final String? jurusan;

  ClassItem({
    required this.id,
    required this.code,
    required this.name,
    this.tingkat,
    this.jurusan,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'] ?? json['class_id'] ?? json['code'] ?? '',
      code: (json['code'] ?? json['kode'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['nama'] ?? json['kelas'] ?? '').toString(),
      tingkat: json['tingkat'] is num ? (json['tingkat'] as num).toInt() : int.tryParse(json['tingkat']?.toString() ?? ''),
      jurusan: json['jurusan']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (tingkat != null) 'tingkat': tingkat,
      if (jurusan != null) 'jurusan': jurusan,
    };
  }
}

/// Model untuk siswa yang telah melakukan presensi (Sudah Hadir)
class HadirStudent {
  final String nis;
  final String nama;
  final String waktuMasuk;
  final String metode; // 'Selfie', 'NFC Tap', 'Bluetooth'
  final String status; // 'Tepat Waktu', 'Terlambat'
  final String? fotoUrl;

  HadirStudent({
    required this.nis,
    required this.nama,
    required this.waktuMasuk,
    required this.metode,
    required this.status,
    this.fotoUrl,
  });

  factory HadirStudent.fromJson(Map<String, dynamic> json) {
    return HadirStudent(
      nis: (json['nis'] ?? json['student_id'] ?? '').toString(),
      nama: (json['nama'] ?? json['name'] ?? 'Siswa').toString(),
      waktuMasuk: (json['waktu_masuk'] ?? json['waktu'] ?? json['time'] ?? '-').toString(),
      metode: (json['metode'] ?? json['method'] ?? 'Presensi').toString(),
      status: (json['status'] ?? json['keterangan'] ?? 'Hadir').toString(),
      fotoUrl: json['foto_url'] ?? json['photo_url'] ?? json['foto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nis': nis,
      'nama': nama,
      'waktu_masuk': waktuMasuk,
      'metode': metode,
      'status': status,
      if (fotoUrl != null) 'foto_url': fotoUrl,
    };
  }
}

/// Model untuk siswa yang belum hadir / belum presensi
class BelumHadirStudent {
  final String nis;
  final String nama;
  final String keterangan;

  BelumHadirStudent({
    required this.nis,
    required this.nama,
    required this.keterangan,
  });

  factory BelumHadirStudent.fromJson(Map<String, dynamic> json) {
    return BelumHadirStudent(
      nis: (json['nis'] ?? json['student_id'] ?? '').toString(),
      nama: (json['nama'] ?? json['name'] ?? 'Siswa').toString(),
      keterangan: (json['keterangan'] ?? json['status'] ?? 'Belum Ada Keterangan').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nis': nis,
      'nama': nama,
      'keterangan': keterangan,
    };
  }
}

/// Model rangkuman kehadiran satu kelas hari ini dari GET /api/presence/today-by-class
class ClassAttendanceSummary {
  final String date;
  final String generatedAt;
  final dynamic classId;
  final String className;
  final int totalSiswa;
  final int totalHadir;
  final int totalBelumHadir;
  final String persentaseKehadiran;
  final List<HadirStudent> hadirList;
  final List<BelumHadirStudent> belumHadirList;

  ClassAttendanceSummary({
    required this.date,
    required this.generatedAt,
    required this.classId,
    required this.className,
    required this.totalSiswa,
    required this.totalHadir,
    required this.totalBelumHadir,
    required this.persentaseKehadiran,
    required this.hadirList,
    required this.belumHadirList,
  });

  factory ClassAttendanceSummary.fromJson(Map<String, dynamic> json) {
    // Parsing Kelas Info
    dynamic cId = '';
    String cName = 'Kelas';
    if (json['kelas'] is Map) {
      cId = json['kelas']['id'] ?? json['kelas']['code'] ?? '';
      cName = (json['kelas']['name'] ?? json['kelas']['nama'] ?? 'Kelas').toString();
    } else if (json['kelas'] != null) {
      cName = json['kelas'].toString();
      cId = cName;
    }

    // Parsing Summary
    final summary = json['summary'] is Map ? json['summary'] as Map<String, dynamic> : <String, dynamic>{};
    final int total = summary['total_siswa'] is num
        ? (summary['total_siswa'] as num).toInt()
        : (json['total_siswa'] is num ? (json['total_siswa'] as num).toInt() : 0);
    final int hadir = summary['hadir'] is num
        ? (summary['hadir'] as num).toInt()
        : (json['total_hadir'] is num ? (json['total_hadir'] as num).toInt() : 0);
    final int belum = summary['belum_hadir'] is num
        ? (summary['belum_hadir'] as num).toInt()
        : (json['total_belum_hadir'] is num ? (json['total_belum_hadir'] as num).toInt() : 0);
    final String pct = (summary['persentase_kehadiran'] ?? json['persentase'] ??
        (total > 0 ? '${((hadir / total) * 100).toStringAsFixed(1)}%' : '0%')).toString();

    // Parsing List Hadir
    final rawHadir = json['hadir_list'] ?? json['data_hadir'] ?? json['hadir'] ?? [];
    List<HadirStudent> hList = [];
    if (rawHadir is List) {
      hList = rawHadir
          .whereType<Map<String, dynamic>>()
          .map((e) => HadirStudent.fromJson(e))
          .toList();
    }

    // Parsing List Belum Hadir
    final rawBelum = json['belum_hadir_list'] ?? json['data_belum_hadir'] ?? json['belum_hadir'] ?? [];
    List<BelumHadirStudent> bList = [];
    if (rawBelum is List) {
      bList = rawBelum
          .whereType<Map<String, dynamic>>()
          .map((e) => BelumHadirStudent.fromJson(e))
          .toList();
    }

    return ClassAttendanceSummary(
      date: (json['date'] ?? json['tanggal'] ?? '').toString(),
      generatedAt: (json['generated_at'] ?? json['waktu_generate'] ?? '').toString(),
      classId: cId,
      className: cName,
      totalSiswa: total > 0 ? total : (hList.length + bList.length),
      totalHadir: hadir > 0 ? hadir : hList.length,
      totalBelumHadir: belum > 0 ? belum : bList.length,
      persentaseKehadiran: pct,
      hadirList: hList,
      belumHadirList: bList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': 'success',
      'date': date,
      'generated_at': generatedAt,
      'kelas': {
        'id': classId,
        'name': className,
      },
      'summary': {
        'total_siswa': totalSiswa,
        'hadir': totalHadir,
        'belum_hadir': totalBelumHadir,
        'persentase_kehadiran': persentaseKehadiran,
      },
      'hadir_list': hadirList.map((e) => e.toJson()).toList(),
      'belum_hadir_list': belumHadirList.map((e) => e.toJson()).toList(),
    };
  }

  String toRawJson() => jsonEncode(toJson());

  static ClassAttendanceSummary? fromRawJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ClassAttendanceSummary.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
