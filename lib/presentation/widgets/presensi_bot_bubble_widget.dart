import 'package:flutter/material.dart';
import '../../data/models/class_attendance_model.dart';

/// Widget Bubble Kartu Bot Presensi untuk BaknusChat
class PresensiBotBubbleWidget extends StatefulWidget {
  final ClassAttendanceSummary? summary;
  final List<ClassItem>? classList;
  final bool isDark;
  final Function(ClassItem selectedClass)? onClassSelected;

  const PresensiBotBubbleWidget({
    super.key,
    this.summary,
    this.classList,
    required this.isDark,
    this.onClassSelected,
  });

  @override
  State<PresensiBotBubbleWidget> createState() => _PresensiBotBubbleWidgetState();
}

class _PresensiBotBubbleWidgetState extends State<PresensiBotBubbleWidget> {
  // 0: Sudah Hadir, 1: Belum Hadir
  int _activeTabIndex = 0;
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // Jika menampilkan daftar pilihan kelas
    if (widget.classList != null && widget.classList!.isNotEmpty && widget.summary == null) {
      return _buildClassSelectionCard();
    }

    // Jika menampilkan rekap kehadiran kelas
    if (widget.summary != null) {
      return _buildSummaryCard(widget.summary!);
    }

    return const SizedBox.shrink();
  }

  // ==================== 1. KARTU DAFTAR PILIHAN KELAS ====================
  Widget _buildClassSelectionCard() {
    final classes = widget.classList!;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFFE11D48),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '📋 Pilih Kelas Presensi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Silakan ketuk kelas di bawah untuk memuat data kehadiran hari ini:',
            style: TextStyle(
              fontSize: 11.5,
              color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: classes.map((c) {
                  return ActionChip(
                    avatar: const Icon(
                      Icons.people_alt_rounded,
                      size: 14,
                      color: Color(0xFFE11D48),
                    ),
                    label: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: widget.isDark
                        ? const Color(0xFF2A1520)
                        : const Color(0xFFFFECEF),
                    side: const BorderSide(
                      color: Color(0xFFFB7185),
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onPressed: () {
                      if (widget.onClassSelected != null) {
                        widget.onClassSelected!(c);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. KARTU REKAP KEHADIRAN KELAS ====================
  Widget _buildSummaryCard(ClassAttendanceSummary summary) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF3B0813) : const Color(0xFFFFD1D9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
            blurRadius: 10,
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

          // Kartu Indikator Ringkas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildIndicatorSummary(summary),
          ),

          // Tab Pilihan: Sudah Hadir vs Belum Hadir
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildTabButtons(summary),
          ),

          const SizedBox(height: 6),

          // Accordion / Content List
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _activeTabIndex == 0
                  ? _buildHadirList(summary.hadirList)
                  : _buildBelumHadirList(summary.belumHadirList),
            ),

          // Footer Toggle Expand / Collapse
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded ? 'Sembunyikan Rincian Siswa' : 'Lihat Rincian Siswa',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: const Color(0xFFE11D48),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header Card
  Widget _buildHeader(ClassAttendanceSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Rekap Kehadiran: ${summary.className}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  summary.generatedAt.isNotEmpty
                      ? '${summary.date} • ${summary.generatedAt}'
                      : summary.date,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'BaknusAttend',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kartu Indikator Ringkas
  Widget _buildIndicatorSummary(ClassAttendanceSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF281822) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFB7185).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricCol('Total', '${summary.totalSiswa}', Colors.blue.shade600),
          _buildMetricDivider(),
          _buildMetricCol('Hadir', '${summary.totalHadir}', const Color(0xFF059669)),
          _buildMetricDivider(),
          _buildMetricCol('Belum', '${summary.totalBelumHadir}', const Color(0xFFD97706)),
          _buildMetricDivider(),
          _buildMetricCol('Persentase', summary.persentaseKehadiran, const Color(0xFFE11D48)),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, Color valColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 22,
      color: Colors.grey.withValues(alpha: 0.25),
    );
  }

  // Tab Buttons: Sudah Hadir & Belum Hadir
  Widget _buildTabButtons(ClassAttendanceSummary summary) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF14141E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 0
                      ? const Color(0xFF059669)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '🟢 Sudah Hadir (${summary.hadirList.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _activeTabIndex == 0
                        ? Colors.white
                        : (widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 1
                      ? const Color(0xFFD97706)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '⏳ Belum Hadir (${summary.belumHadirList.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _activeTabIndex == 1
                        ? Colors.white
                        : (widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List Siswa Sudah Hadir
  Widget _buildHadirList(List<HadirStudent> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Belum ada siswa yang melakukan presensi hari ini.',
            style: TextStyle(
              fontSize: 11.5,
              color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        itemBuilder: (ctx, idx) {
          final s = list[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                // Nomor Urut
                SizedBox(
                  width: 20,
                  child: Text(
                    '${idx + 1}.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ),

                // Foto Selfie Thumbnail (jika ada)
                if (s.fotoUrl != null && s.fotoUrl!.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showPhotoDialog(ctx, s.nama, s.fotoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        s.fotoUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.person, size: 18, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Nama & NIS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nama,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'NIS: ${s.nis} • ⏰ ${s.waktuMasuk}',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Badges: Metode & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMethodBadge(s.metode),
                    const SizedBox(height: 2),
                    _buildStatusBadge(s.status),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // List Siswa Belum Hadir
  Widget _buildBelumHadirList(List<BelumHadirStudent> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '🎉 Luar biasa! Semua siswa telah presensi.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF059669),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        itemBuilder: (ctx, idx) {
          final s = list[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${idx + 1}.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nama,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'NIS: ${s.nis}',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade600, width: 0.6),
                  ),
                  child: Text(
                    s.keterangan,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Badge Metode Presensi
  Widget _buildMethodBadge(String method) {
    final lower = method.toLowerCase();
    IconData iconData = Icons.touch_app_rounded;
    Color badgeColor = const Color(0xFF0284C7); // Light blue

    if (lower.contains('selfie') || lower.contains('foto')) {
      iconData = Icons.camera_alt_rounded;
      badgeColor = const Color(0xFF7C3AED); // Purple
    } else if (lower.contains('nfc') || lower.contains('tap') || lower.contains('kartu')) {
      iconData = Icons.nfc_rounded;
      badgeColor = const Color(0xFF059669); // Green
    } else if (lower.contains('blue') || lower.contains('ble') || lower.contains('wemos')) {
      iconData = Icons.bluetooth_rounded;
      badgeColor = const Color(0xFF2563EB); // Royal Blue
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 9.5, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            method,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // Badge Status Hadir
  Widget _buildStatusBadge(String status) {
    final isTerlambat = status.toLowerCase().contains('terlambat') ||
        status.toLowerCase().contains('telat');
    final color = isTerlambat ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Dialog Preview Foto Selfie
  void _showPhotoDialog(BuildContext context, String name, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFE11D48),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Foto Selfie: $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 150,
                    child: Center(
                      child: Text('Gagal memuat foto selfie.'),
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
