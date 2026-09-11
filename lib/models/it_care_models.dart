// lib/models/it_care_models.dart

class ITCareUser {
  final String id;
  final String name;
  final String email;
  final String role; // "Pelapor", "Teknisi", "Admin"

  ITCareUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isTechnician =>
      role.toLowerCase() == 'teknisi' || role.toLowerCase() == 'admin';

  factory ITCareUser.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString().trim();
    final rawId = (json['id'] ?? json['userId'] ?? '').toString().trim();
    final id = rawId.isNotEmpty ? rawId : (email.isNotEmpty ? email : 'pelapor_user');
    final rawName = (json['name'] ?? json['userName'] ?? json['displayName'] ?? '').toString().trim();
    final name = rawName.isNotEmpty ? rawName : (email.isNotEmpty ? email.split('@').first : 'Pelapor');

    return ITCareUser(
      id: id,
      name: name,
      email: email,
      role: (json['role'] ?? json['userRole'] ?? 'Pelapor').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };
}

class TicketItem {
  final int id;
  final String ticketCode;
  final String title;
  final String? description;
  final String category;
  final String location;
  final String priority;
  final String status;
  final String? requesterId;
  final String requesterName;
  final String? requesterEmail;
  final String assignedTechnicianName;
  final String createdAt;
  final String? updatedAt;
  final String? resolvedAt;
  final String? dueDate;
  final bool isOverdue;
  final int commentsCount;
  final int? rating;
  final String? feedbackComments;
  final List<TicketComment> comments;

  TicketItem({
    required this.id,
    required this.ticketCode,
    required this.title,
    this.description,
    required this.category,
    required this.location,
    required this.priority,
    required this.status,
    this.requesterId,
    required this.requesterName,
    this.requesterEmail,
    required this.assignedTechnicianName,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.dueDate,
    this.isOverdue = false,
    this.commentsCount = 0,
    this.rating,
    this.feedbackComments,
    this.comments = const [],
  });

  bool get isResolved =>
      status.toLowerCase() == 'selesai' || status.toLowerCase() == 'ditutup';

  bool get isInProgress =>
      status.toLowerCase() == 'diproses' ||
      status.toLowerCase() == 'menunggasparepart';

  bool get isNew => status.toLowerCase() == 'baru';

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    List<TicketComment> commentsList = [];
    if (json['comments'] != null && json['comments'] is List) {
      commentsList = (json['comments'] as List)
          .map((c) => TicketComment.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return TicketItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ticketCode: (json['ticketCode'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      category: (json['category'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      priority: (json['priority'] ?? 'Sedang').toString(),
      status: (json['status'] ?? 'Baru').toString(),
      requesterId: json['requesterId']?.toString(),
      requesterName: (json['requesterName'] ?? 'Anonim').toString(),
      requesterEmail: json['requesterEmail']?.toString(),
      assignedTechnicianName:
          (json['assignedTechnicianName'] ?? 'Belum Ditugaskan').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: json['updatedAt']?.toString(),
      resolvedAt: json['resolvedAt']?.toString(),
      dueDate: json['dueDate']?.toString(),
      isOverdue: json['isOverdue'] == true,
      commentsCount: int.tryParse(json['commentsCount']?.toString() ?? '0') ??
          commentsList.length,
      rating: json['rating'] != null
          ? int.tryParse(json['rating'].toString())
          : null,
      feedbackComments: json['feedbackComments']?.toString(),
      comments: commentsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketCode': ticketCode,
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'priority': priority,
        'status': status,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterEmail': requesterEmail,
        'assignedTechnicianName': assignedTechnicianName,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'resolvedAt': resolvedAt,
        'dueDate': dueDate,
        'isOverdue': isOverdue,
        'commentsCount': commentsCount,
        'rating': rating,
        'feedbackComments': feedbackComments,
        'comments': comments.map((c) => c.toJson()).toList(),
      };
}

class TicketComment {
  final int id;
  final String? userId;
  final String userName;
  final String userRole;
  final String message;
  final bool isInternal;
  final String createdAt;

  TicketComment({
    required this.id,
    this.userId,
    required this.userName,
    required this.userRole,
    required this.message,
    this.isInternal = false,
    required this.createdAt,
  });

  bool get isTechnician =>
      userRole.toLowerCase() == 'teknisi' || userRole.toLowerCase() == 'admin';

  factory TicketComment.fromJson(Map<String, dynamic> json) {
    return TicketComment(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['userId']?.toString(),
      userName: (json['userName'] ?? 'Petugas IT').toString(),
      userRole: (json['userRole'] ?? 'Teknisi').toString(),
      message: (json['message'] ?? '').toString(),
      isInternal: json['isInternal'] == true,
      createdAt: (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'message': message,
        'isInternal': isInternal,
        'createdAt': createdAt,
      };
}

class MetaOptions {
  final List<String> locations;
  final List<String> services;
  final List<String> internetSubIssues;
  final List<String> baknusIdApps;
  final List<String> priorities;
  final List<String> statuses;

  MetaOptions({
    required this.locations,
    required this.services,
    required this.internetSubIssues,
    required this.baknusIdApps,
    required this.priorities,
    required this.statuses,
  });

  factory MetaOptions.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return MetaOptions(
      locations: parseList(json['locations']),
      services: parseList(json['services']),
      internetSubIssues: parseList(json['internetSubIssues']),
      baknusIdApps: parseList(json['baknusIdApps']),
      priorities: parseList(json['priorities']),
      statuses: parseList(json['statuses']),
    );
  }

  static MetaOptions defaultOptions() {
    return MetaOptions(
      locations: [
        '1. Ruang Workshop',
        '2. Ruang Kepsek',
        '3. Ruang Bahagian',
        '4. Wifi lantai 1',
        '5. Ruang BK, Ruang Guru',
        '6. Wifi lantai 2 Timur (deket lab AKT) . Wifi lantai 2 Barat',
        '7. Wifi lantai 2 Selatan',
        '8. Lab Akuntansi',
        '9. Ruang TU Keuangan',
        '10. Ruang Perpustakaan',
        '11. Lab Animasi',
        '12. Lab DKV',
        '13. Ruang TU',
        '14. Lab PK lantai 1',
        '15. Lab PK lantai 2',
        '16. Lab PK Lantai 3',
        '17. Ruang Photografi',
        '18. Lab Pemasaran',
        '19. Lainnya',
      ],
      services: ['Internet', 'BaknusID'],
      internetSubIssues: [
        'Internet tidak terkoneksi',
        'Wi-Fi / LAN tidak nyala',
        'Sinyal Wi-Fi Lemah / RTO',
      ],
      baknusIdApps: [
        'WebsiteBaknus',
        'Baknusmail',
        'BaknusAttend',
        'BaknusDrive',
        'BaknusClass',
      ],
      priorities: ['Rendah', 'Sedang', 'Tinggi', 'Darurat'],
      statuses: ['Baru', 'Diproses', 'MenungguSparepart', 'Selesai', 'Ditutup'],
    );
  }
}

class KpiDashboard {
  final int totalTickets;
  final int newTickets;
  final int inProgressTickets;
  final int pendingPartsTickets;
  final int resolvedTickets;
  final int overdueSlaTickets;
  final double averageRating;
  final Map<String, int> categoryBreakdown;

  KpiDashboard({
    required this.totalTickets,
    required this.newTickets,
    required this.inProgressTickets,
    required this.pendingPartsTickets,
    required this.resolvedTickets,
    required this.overdueSlaTickets,
    required this.averageRating,
    required this.categoryBreakdown,
  });

  factory KpiDashboard.fromJson(Map<String, dynamic> json) {
    Map<String, int> categories = {};
    if (json['categoryBreakdown'] is Map) {
      json['categoryBreakdown'].forEach((k, v) {
        categories[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }

    return KpiDashboard(
      totalTickets: int.tryParse(json['totalTickets']?.toString() ?? '0') ?? 0,
      newTickets: int.tryParse(json['newTickets']?.toString() ?? '0') ?? 0,
      inProgressTickets:
          int.tryParse(json['inProgressTickets']?.toString() ?? '0') ?? 0,
      pendingPartsTickets:
          int.tryParse(json['pendingPartsTickets']?.toString() ?? '0') ?? 0,
      resolvedTickets:
          int.tryParse(json['resolvedTickets']?.toString() ?? '0') ?? 0,
      overdueSlaTickets:
          int.tryParse(json['overdueSlaTickets']?.toString() ?? '0') ?? 0,
      averageRating:
          double.tryParse(json['averageRating']?.toString() ?? '0') ?? 0.0,
      categoryBreakdown: categories,
    );
  }
}

class ITTechnicianStaff {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role; // "Teknisi", "Admin"
  final String roleLabel; // e.g. "Petugas IT (Teknisi)", "Administrator IT"
  final String department; // "Guru", "TU", "Admin"
  final int activeTicketsHandled;
  final int totalResolvedTickets;

  const ITTechnicianStaff({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.roleLabel,
    required this.department,
    this.activeTicketsHandled = 0,
    this.totalResolvedTickets = 0,
  });

  String get avatarInitials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'IT';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory ITTechnicianStaff.fromJson(Map<String, dynamic> json) {
    return ITTechnicianStaff(
      id: (json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['name'] ?? 'Petugas IT').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '-').toString(),
      role: (json['role'] ?? 'Teknisi').toString(),
      roleLabel: (json['roleLabel'] ?? (json['role'] == 'Admin' ? 'Administrator IT' : 'Petugas IT (Teknisi)')).toString(),
      department: (json['department'] ?? 'Guru').toString(),
      activeTicketsHandled: int.tryParse(json['activeTicketsHandled']?.toString() ?? '0') ?? 0,
      totalResolvedTickets: int.tryParse(json['totalResolvedTickets']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': role,
        'roleLabel': roleLabel,
        'department': department,
        'activeTicketsHandled': activeTicketsHandled,
        'totalResolvedTickets': totalResolvedTickets,
      };

  ITTechnicianContact toContact() {
    return ITTechnicianContact(
      name: fullName,
      email: email,
      role: '$roleLabel ($department)',
      description: '$department • $activeTicketsHandled aktif, $totalResolvedTickets selesai',
      avatarInitials: avatarInitials,
    );
  }
}

class ITTechnicianContact {
  final String name;
  final String email;
  final String role;
  final String description;
  final String avatarInitials;

  const ITTechnicianContact({
    required this.name,
    required this.email,
    required this.role,
    required this.description,
    required this.avatarInitials,
  });

  static const List<ITTechnicianContact> defaultStaff = [
    ITTechnicianContact(
      name: 'Frian Prianas',
      email: 'frian_p@smk.baktinusantara666.sch.id',
      role: 'Petugas IT (Teknisi)',
      description: 'Unit Guru • Spesialis Infrastruktur & Jaringan',
      avatarInitials: 'FP',
    ),
    ITTechnicianContact(
      name: 'Septian',
      email: 'septian@smk.baktinusantara666.sch.id',
      role: 'Petugas IT (Teknisi)',
      description: 'Unit TU • Teknisi Lab & Hardware Sekolah',
      avatarInitials: 'SP',
    ),
    ITTechnicianContact(
      name: 'Administrator IT',
      email: 'admin@smk.baktinusantara666.sch.id',
      role: 'Administrator IT',
      description: 'Unit Admin • Manajemen Akun & Cloud BaknusID',
      avatarInitials: 'AD',
    ),
  ];
}

