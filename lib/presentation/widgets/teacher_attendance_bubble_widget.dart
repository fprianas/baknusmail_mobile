import 'package:flutter/material.dart';
import '../../data/models/teacher_attendance_model.dart';

/// Widget Bubble Kartu Bot Kehadiran Guru & TU (@hadir) untuk BaknusChat
class TeacherAttendanceBubbleWidget extends StatefulWidget {
  final TeacherAttendanceSummary? summary;
  final bool isDark;

  const TeacherAttendanceBubbleWidget({
    super.key,
    required this.summary,
    required this.isDark,
  });

  @override
  State<TeacherAttendanceBubbleWidget> createState() =>
      _TeacherAttendanceBubbleWidgetState();
}

class _TeacherAttendanceBubbleWidgetState
    extends State<TeacherAttendanceBubbleWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.6)
              : const Color(0xFFBFDBFE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Card
          _buildHeader(summary),

          // Sub-Header Info / Total Counter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _buildSummaryBar(summary),
          ),

          const SizedBox(height: 2),

          // Isi Daftar Guru & TU yang Sudah Hadir
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildTeacherList(summary.data),
            ),

          // Footer Toggle Expand / Collapse jika data ada
          if (summary.data.isNotEmpty)
            InkWell(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.grey.shade50,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Sembunyikan Daftar Guru'
                          : 'Lihat Daftar Guru (${summary.data.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== HEADER CARD ====================
  Widget _buildHeader(TeacherAttendanceSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF13203C)
            : const Color(0xFFEFF6FF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        border: Border(
          bottom: BorderSide(
            color: widget.isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                : const Color(0xFFDBEAFE),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Kehadiran Guru & TU Hari Ini',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.date.isNotEmpty
                      ? '${summary.date} • Total: ${summary.totalHadir} Orang Hadir'
                      : 'Total: ${summary.totalHadir} Orang Hadir',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${summary.totalHadir} Hadir',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SUMMARY BAR ====================
  Widget _buildSummaryBar(TeacherAttendanceSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF131A2A)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Menampilkan guru & staf TU yang sudah berada di sekolah.',
              style: TextStyle(
                fontSize: 10,
                color: widget.isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LIST GURU & TU ====================
  Widget _buildTeacherList(List<HadirTeacher> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 38,
                color: widget.isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                '📋 Belum ada Guru atau Staf TU yang melakukan presensi masuk hari ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        itemBuilder: (ctx, idx) {
          final t = list[idx];
          return _buildTeacherCard(ctx, t, idx + 1);
        },
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context, HadirTeacher t, int index) {
    final hasPhoto = t.fotoUrl != null && t.fotoUrl!.trim().isNotEmpty;

    // Status Color Coding
    Color statusColor;
    Color statusBgColor;
    final statusLower = t.status.toLowerCase();
    if (statusLower.contains('terlambat')) {
      statusColor = const Color(0xFFD97706); // Amber / Orange
      statusBgColor = const Color(0xFFD97706).withValues(alpha: 0.12);
    } else if (statusLower.contains('dinas')) {
      statusColor = const Color(0xFF2563EB); // Blue
      statusBgColor = const Color(0xFF2563EB).withValues(alpha: 0.12);
    } else {
      statusColor = const Color(0xFF059669); // Green (Tepat Waktu)
      statusBgColor = const Color(0xFF059669).withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar / Foto Selfie Lingkaran
          GestureDetector(
            onTap: hasPhoto
                ? () => _showPhotoDialog(context, t.nama, t.fotoUrl!)
                : null,
            child: Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: hasPhoto
                        ? Image.network(
                            t.fotoUrl!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: widget.isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                child: const Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                _buildInitialAvatar(t.nama),
                          )
                        : _buildInitialAvatar(t.nama),
                  ),
                ),
                if (hasPhoto)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Detail Info Guru
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Lengkap
                Text(
                  t.nama,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1.5),

                // NIP & Jabatan
                Text(
                  '${t.role} • ${t.jabatan}${t.nip != '-' ? ' (${t.nip})' : ''}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),

                // Badges Bar: Jam Masuk, Status, Metode
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    // Badge Jam Masuk
                    _buildBadge(
                      label: '⏰ ${t.waktuMasuk} WIB',
                      textColor: widget.isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1D4ED8),
                      bgColor: widget.isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFEFF6FF),
                    ),

                    // Badge Status (Tepat Waktu / Terlambat / Dinas Luar)
                    _buildBadge(
                      label: t.status,
                      textColor: statusColor,
                      bgColor: statusBgColor,
                    ),

                    // Badge Metode Presensi
                    _buildBadge(
                      label: t.metode,
                      textColor: widget.isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      bgColor: widget.isDark
                          ? Colors.white10
                          : Colors.grey.shade100,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String name) {
    final clean = name.replaceAll(RegExp(r'^(Bpk\.|Ibu\.|Pak\.|Bu\.)\s*', caseSensitive: false), '').trim();
    final initial = clean.isNotEmpty ? clean[0].toUpperCase() : 'G';
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ==================== DIALOG PREVIEW FOTO SELFIE ====================
  void _showPhotoDialog(BuildContext context, String nama, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFF2563EB),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Foto Presensi: $nama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // Foto Selfie Ukuran Penuh
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              color: Colors.black,
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            color: Colors.white54, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Gagal memuat foto selfie',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
