import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/attendance_model.dart';
import '../../data/services/attendance_service.dart';
import '../../providers/attendance_provider.dart';
import 'nfc_attendance_sheet.dart';
import 'bluetooth_attendance_sheet.dart';

class SelfieAttendanceCard extends StatefulWidget {
  final String userEmail;
  final String? userPassword;

  const SelfieAttendanceCard({
    super.key,
    required this.userEmail,
    this.userPassword,
  });

  @override
  State<SelfieAttendanceCard> createState() => _SelfieAttendanceCardState();
}

class _SelfieAttendanceCardState extends State<SelfieAttendanceCard> {
  final TextEditingController _lokasiController = TextEditingController();
  int _selectedAttendanceMethod = 0; // 0: Selfie Wajah, 1: Tap Kartu NFC

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().initialize(
            userEmail: widget.userEmail,
            password: widget.userPassword,
            checkGps: true,
          );
    });
  }

  @override
  void dispose() {
    _lokasiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attend = context.watch<AttendanceProvider>();

    final status = attend.statusResponse;
    final hasMaster = attend.hasFaceMaster;
    final canAttend = attend.canAttend;
    final presensiType = attend.presensiType;
    final isDinasLuar = attend.isDinasLuar;
    final isWithinRadius = attend.isWithinRadius;
    final distance = attend.distanceToSchool;
    final schoolSetting = attend.schoolSetting;

    // Tentukan warna tema berdasarkan status
    Color typeColor = const Color(0xFF10B981); // Emerald green default
    IconData typeIcon = Icons.login_rounded;
    if (presensiType.toLowerCase().contains('pulang')) {
      typeColor = const Color(0xFFF59E0B); // Amber
      typeIcon = Icons.logout_rounded;
    } else if (presensiType.toLowerCase().contains('selesai')) {
      typeColor = const Color(0xFF3B82F6); // Blue
      typeIcon = Icons.check_circle_rounded;
    } else if (presensiType.toLowerCase().contains('libur')) {
      typeColor = Colors.grey;
      typeIcon = Icons.beach_access_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== 1. HEADER MODUL ====================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      color: typeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presensi Selfie & GPS',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'CompreFace AI (≥90%)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              // Badge Status & Tipe Presensi Hari Ini
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attend.hasAuthToken) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Sinkron',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Badge Tipe Presensi Hari Ini
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 14, color: typeColor),
                        const SizedBox(width: 5),
                        Text(
                          presensiType,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==================== 1.5 KARTU STATUS KEHADIRAN HARI INI ====================
          _buildTodayPresenceSummaryCard(attend, isDark),
          const SizedBox(height: 14),

          // ==================== 2. INDIKATOR GEOFENCING GPS ====================
          _buildGeofencingCard(attend, isDark, distance, isWithinRadius, schoolSetting),
          const SizedBox(height: 14),

          // ==================== 3. PERINGATAN WAJAH MASTER / STATUS SESI ====================
          // Jika akun sudah sinkron, Card Sesi Presensi Belum Terhubung DIHILANGKAN
          if (!attend.hasAuthToken && status == null && !attend.isLoading) ...[
            _buildLoginRequiredCard(context, attend, isDark),
            const SizedBox(height: 14),
          ] else if (!hasMaster && attend.hasAuthToken) ...[
            _buildMissingMasterCard(attend, isDark),
            const SizedBox(height: 14),
          ],

          // ==================== 4. FORM PENUGASAN DINAS LUAR ====================
          _buildDinasLuarSection(attend, isDark, isDinasLuar),
          const SizedBox(height: 16),

          // ==================== 5. TOMBOL AKSI UTAMA ====================
          _buildActionButtons(context, attend, hasMaster, canAttend, presensiType, isDinasLuar, isWithinRadius),

          // ==================== 6. RIWAYAT TAP HARI INI ====================
          if (status != null && status.todayRecords.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catatan Presensi Hari Ini',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${status.todayRecords.length} Tap',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...status.todayRecords.map((r) => _buildTodayRecordItem(r, isDark)),
          ],
        ],
      ),
    );
  }

  // ==================== KARTU RINGKASAN STATUS KEHADIRAN HARI INI ====================
  Widget _buildTodayPresenceSummaryCard(AttendanceProvider attend, bool isDark) {
    final bool hasIn = attend.hasClockedIn;
    final bool hasOut = attend.hasClockedOut;
    final bool isCompleted = attend.isCompletedToday;
    final inRecord = attend.recordMasuk;
    final outRecord = attend.recordPulang;

    // Tentukan status teks ringkasan utama
    String summaryTitle = 'Belum Melakukan Presensi Hari Ini';
    String summarySubtitle = 'Silakan tap tombol di bawah untuk presensi masuk.';
    Color summaryColor = const Color(0xFF64748B); // Slate default
    IconData summaryIcon = Icons.info_outline_rounded;

    if (isCompleted) {
      summaryTitle = 'Presensi Lengkap Hari Ini';
      summarySubtitle = 'Masuk (${inRecord?.waktu ?? 'Tercatat'}) & Pulang (${outRecord?.waktu ?? 'Tercatat'})';
      summaryColor = const Color(0xFF10B981); // Emerald Green
      summaryIcon = Icons.check_circle_rounded;
    } else if (hasIn) {
      summaryTitle = 'Sudah Absen Masuk';
      summarySubtitle = 'Pukul ${inRecord?.waktu ?? 'Tercatat'} • Belum presensi pulang';
      summaryColor = const Color(0xFFF59E0B); // Amber
      summaryIcon = Icons.access_time_filled_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: summaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: summaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Ringkasan Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: summaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(summaryIcon, size: 18, color: summaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryTitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      summarySubtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: summaryColor.withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          // 2 Kolom: Presensi Masuk & Presensi Pulang
          Row(
            children: [
              // Kolom 1: Presensi Masuk
              Expanded(
                child: _buildAttendanceTypeBlock(
                  title: 'Presensi Masuk',
                  isDone: hasIn,
                  time: inRecord?.waktu ?? (hasIn ? 'Tercatat' : '--:--'),
                  icon: Icons.login_rounded,
                  activeColor: const Color(0xFF10B981),
                  isDark: isDark,
                  extraInfo: inRecord?.similarity != null
                      ? 'AI ${inRecord!.similarity!.toStringAsFixed(1)}%'
                      : (inRecord?.isDinasLuar == true ? 'Dinas Luar' : (hasIn ? 'GPS OK' : null)),
                ),
              ),
              const SizedBox(width: 10),
              // Kolom 2: Presensi Pulang
              Expanded(
                child: _buildAttendanceTypeBlock(
                  title: 'Presensi Pulang',
                  isDone: hasOut,
                  time: outRecord?.waktu ?? (hasOut ? 'Tercatat' : (hasIn ? 'Belum Pulang' : '--:--')),
                  icon: Icons.logout_rounded,
                  activeColor: hasOut ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  isDark: isDark,
                  extraInfo: outRecord?.similarity != null
                      ? 'AI ${outRecord!.similarity!.toStringAsFixed(1)}%'
                      : (outRecord?.isDinasLuar == true ? 'Dinas Luar' : (hasIn && !hasOut ? 'Siap Absen' : null)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTypeBlock({
    required String title,
    required bool isDone,
    required String time,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
    String? extraInfo,
  }) {
    final statusBg = isDone
        ? activeColor.withValues(alpha: 0.12)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03));
    final borderColor = isDone
        ? activeColor.withValues(alpha: 0.3)
        : (isDark ? AppColors.darkBorder : Colors.grey.shade200);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isDone ? activeColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDone)
                Icon(Icons.check_circle_rounded, size: 14, color: activeColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDone
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            ),
          ),
          if (extraInfo != null) ...[
            const SizedBox(height: 2),
            Text(
              extraInfo,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDone ? activeColor : const Color(0xFFD97706),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== WIDGET CARD GEOFENCING ====================
  Widget _buildGeofencingCard(
    AttendanceProvider attend,
    bool isDark,
    double? distance,
    bool isWithinRadius,
    SchoolSetting school,
  ) {
    final bool isChecking = attend.isCheckingLocation;
    final String? locError = attend.locationErrorMessage;

    Color badgeColor = const Color(0xFF10B981);
    String statusText = 'Di Dalam Radius Sekolah';
    IconData statusIcon = Icons.check_circle_rounded;

    if (locError != null) {
      badgeColor = const Color(0xFFEF4444);
      statusText = 'GPS Bermasalah';
      statusIcon = Icons.warning_amber_rounded;
    } else if (isChecking) {
      badgeColor = const Color(0xFF3B82F6);
      statusText = 'Mendeteksi Posisi GPS...';
      statusIcon = Icons.sync_rounded;
    } else if (distance != null && !isWithinRadius) {
      badgeColor = const Color(0xFFEAB308);
      statusText = 'Di Luar Radius Sekolah';
      statusIcon = Icons.location_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pin_drop_rounded,
                    size: 18,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Geofencing GPS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Perbarui Koordinat GPS',
                onPressed: attend.isCheckingLocation
                    ? null
                    : () => attend.checkLocationAndDistance(),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Info Lokasi Server
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${school.name} (Radius ${school.radiusMeters.toStringAsFixed(0)}m)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris Detail Jarak Real-time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distance != null && locError == null) ...[
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Jarak GPS Anda: ',
                              style: TextStyle(fontSize: 12),
                            ),
                            TextSpan(
                              text: '${distance.toStringAsFixed(0)} meter ',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isWithinRadius
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEAB308),
                              ),
                            ),
                            TextSpan(
                              text: '(Maks ${school.radiusMeters.toStringAsFixed(0)}m)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (locError != null) ...[
                      Text(
                        locError,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFEF4444),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Text(
                        'Menghubungkan ke satelit GPS...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET SESI BELUM TERHUBUNG ====================
  Widget _buildLoginRequiredCard(BuildContext context, AttendanceProvider attend, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'Sesi Presensi Belum Terhubung',
                style: TextStyle(
                  color: Color(0xFF1E40AF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Hubungkan akun presensi untuk menyinkronkan status kehadiran & data wajah master yang sudah terdaftar di web.',
            style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.sync_lock_rounded, size: 18),
              label: const Text(
                'Sinkronkan Akun Presensi Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              onPressed: () => _showLoginDialog(context, attend),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog(BuildContext context, AttendanceProvider attend) {
    final usernameController = TextEditingController(
      text: widget.userEmail.isNotEmpty ? widget.userEmail : '',
    );
    final passwordController = TextEditingController(
      text: widget.userPassword ?? '',
    );
    bool obscurePassword = true;
    bool isLoggingIn = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text('Hubungkan Akun Presensi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan kata sandi akun Anda untuk menyambungkan otentikasi Bearer Token:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username / Email',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoggingIn ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: isLoggingIn
                    ? null
                    : () async {
                        final u = usernameController.text.trim();
                        final p = passwordController.text;
                        if (u.isEmpty || p.isEmpty) {
                          setDialogState(() {
                            localError = 'Username dan kata sandi wajib diisi.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoggingIn = true;
                          localError = null;
                        });

                        final success = await attend.loginManual(u, p);
                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Berhasil menghubungkan sesi presensi!'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isLoggingIn = false;
                            localError = attend.errorMessage ?? 'Gagal masuk. Periksa username & kata sandi.';
                          });
                        }
                      },
                child: isLoggingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Hubungkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== WIDGET WAJAH MASTER BELUM TERDAFTAR ====================
  Widget _buildMissingMasterCard(AttendanceProvider attend, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Foto Wajah Master Belum Terdaftar',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sistem AI CompreFace memerlukan foto wajah patokan (master) satu kali agar bisa memvalidasi presensi selfie Anda.',
            style: TextStyle(color: Color(0xFF78350F), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: attend.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text(
                'Daftarkan Foto Wajah Master Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              onPressed: attend.isSubmitting
                  ? null
                  : () => _handleRegisterMasterFace(context, attend),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET DINAS LUAR ====================
  Widget _buildDinasLuarSection(AttendanceProvider attend, bool isDark, bool isDinasLuar) {
    if (isDinasLuar &&
        _lokasiController.text.isEmpty &&
        attend.lokasiDinasLuar.isNotEmpty &&
        attend.lokasiDinasLuar != 'Penugasan Luar / DUDI') {
      _lokasiController.text = attend.lokasiDinasLuar;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business_center_rounded,
                  size: 16,
                  color: isDinasLuar ? const Color(0xFF3B82F6) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Penugasan Dinas Luar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            Switch.adaptive(
              value: isDinasLuar,
              activeTrackColor: const Color(0xFF3B82F6),
              activeThumbColor: Colors.white,
              onChanged: (val) async {
                if (val) {
                  if (_lokasiController.text.trim().isEmpty) {
                    final loc = await _promptLokasiDinasLuar(context);
                    if (loc != null && loc.trim().isNotEmpty) {
                      _lokasiController.text = loc;
                      attend.setDinasLuar(true, lokasi: loc);
                    }
                  } else {
                    attend.setDinasLuar(true, lokasi: _lokasiController.text.trim());
                  }
                } else {
                  attend.setDinasLuar(false);
                }
              },
            ),
          ],
        ),
        if (isDinasLuar) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _lokasiController,
            onChanged: (text) => attend.setLokasiDinasLuar(text),
            decoration: InputDecoration(
              hintText: 'Contoh: Kantor DUDI, PKL di Telkom, Seminar, dll.',
              hintStyle: const TextStyle(fontSize: 12),
              labelText: 'Nama / Alamat Lokasi Dinas Luar *',
              labelStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.map_rounded, size: 18),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '* Wajib diisi jika presensi di luar radius sekolah.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ],
    );
  }

  // ==================== TOMBOL AKSI UTAMA ====================
  Widget _buildActionButtons(
    BuildContext context,
    AttendanceProvider attend,
    bool hasMaster,
    bool canAttend,
    String presensiType,
    bool isDinasLuar,
    bool isWithinRadius,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCompleted = presensiType.toLowerCase().contains('selesai');
    final bool isHoliday = presensiType.toLowerCase().contains('libur');

    if (isHoliday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_rounded, color: Colors.grey, size: 22),
            SizedBox(width: 10),
            Text(
              'Hari ini adalah hari libur sekolah.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // ==================== CEK APAKAH PRESENSI SUDAH SELESAI ====================
    // Jika user sudah tap masuk & pulang, atau sudah clocked out hari ini:
    // Fasilitas presensi (Selfie & NFC) dikunci / tidak tersedia lagi
    final bool isDoneToday = isCompleted || attend.isCompletedToday || attend.hasClockedOut;

    if (isDoneToday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'Presensi Hari Ini Telah Selesai',
              style: TextStyle(
                color: Color(0xFF065F46),
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Anda telah menyelesaikan presensi Masuk & Pulang hari ini.\nFasilitas presensi mandiri (Selfie & Tap NFC) telah ditutup.',
              style: TextStyle(
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final bool isSubmitting = attend.isSubmitting;
    final String actionType = attend.hasClockedIn ? 'Pulang' : 'Masuk';
    final Color actionColor = attend.hasClockedIn ? const Color(0xFFD97706) : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================== TAB PILIHAN METODE PRESENSI ====================
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              // Tab 0: Selfie Wajah
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedAttendanceMethod = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedAttendanceMethod == 0
                          ? (isDark ? const Color(0xFF2563EB) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedAttendanceMethod == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 17,
                          color: _selectedAttendanceMethod == 0
                              ? (isDark ? Colors.white : const Color(0xFF2563EB))
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Selfie Wajah',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedAttendanceMethod == 0 ? FontWeight.bold : FontWeight.w500,
                            color: _selectedAttendanceMethod == 0
                                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab 1: Tap Kartu NFC
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedAttendanceMethod = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedAttendanceMethod == 1
                          ? (isDark ? const Color(0xFF2563EB) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedAttendanceMethod == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contactless_rounded,
                          size: 17,
                          color: _selectedAttendanceMethod == 1
                              ? (isDark ? Colors.white : const Color(0xFF2563EB))
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap NFC',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedAttendanceMethod == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _selectedAttendanceMethod == 1
                                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab 2: Bluetooth Wemos
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedAttendanceMethod = 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedAttendanceMethod == 2
                          ? (isDark ? const Color(0xFF2563EB) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedAttendanceMethod == 2
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 17,
                          color: _selectedAttendanceMethod == 2
                              ? (isDark ? Colors.white : const Color(0xFF2563EB))
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BLE Wemos',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedAttendanceMethod == 2 ? FontWeight.bold : FontWeight.w500,
                            color: _selectedAttendanceMethod == 2
                                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ==================== KONTEN TOMBOL AKSI SESUAI TAB ====================
        if (_selectedAttendanceMethod == 0) ...[
          // TAB 0: SELFIE WAJAH
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded, size: 22),
              label: Text(
                isSubmitting
                    ? 'Memproses CompreFace AI...'
                    : 'Buka Kamera & Absen $actionType',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: isSubmitting ? null : () => _handleSelfieAttendance(context, attend),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '💡 Foto wajah selfie tegak lurus kamera (AI CompreFace ≥90%).',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ] else if (_selectedAttendanceMethod == 1) ...[
          // TAB 1: TAP KARTU NFC
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.contactless_rounded, size: 22),
              label: Text(
                isSubmitting
                    ? 'Menghubungkan Server...'
                    : 'Tempelkan Kartu NFC & Absen $actionType',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: isSubmitting ? null : () => _handleNfcAttendance(context, attend),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '💡 Tempelkan kartu fisik pelajar / pegawai ke sensor NFC di belakang HP.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ] else ...[
          // TAB 2: BLUETOOTH BLE OFFLINE WEMOS
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded, size: 22),
              label: Text(
                isSubmitting
                    ? 'Menghubungkan Bluetooth...'
                    : 'Presensi Bluetooth Wemos & Absen $actionType',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: isSubmitting ? null : () => _handleBluetoothAttendance(context, attend),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '💡 Dekatkan smartphone ke perangkat Wemos D1 R32 (< 5 meter).',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==================== ITEM RIWAYAT TAP HARI INI ====================
  Widget _buildTodayRecordItem(AttendanceRecordItem record, bool isDark) {
    final isPulang = record.type?.toLowerCase().contains('pulang') == true;
    final color = isPulang ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPulang ? Icons.logout_rounded : Icons.login_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absen ${record.type ?? 'Presensi'}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    record.waktu ?? '--:--',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (record.similarity != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'AI ${record.similarity!.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== LOGIKA SUBMIT & ERROR DIALOGS ====================

  /// Dialog untuk meminta nama/lokasi penugasan dinas luar jika belum terisi atau diaktifkan
  Future<String?> _promptLokasiDinasLuar(BuildContext context, {String initialValue = ''}) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.business_center_rounded, color: Color(0xFF3B82F6), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lokasi Penugasan Dinas Luar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mohon isi nama instansi, kantor, atau tempat penugasan dinas luar Anda agar tercatat akurat pada sistem presensi.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nama / Alamat Tempat Dinas Luar *',
                  labelStyle: const TextStyle(fontSize: 12),
                  hintText: 'Contoh: PT Telkom Indonesia, Seminar di UPI, dll.',
                  hintStyle: const TextStyle(fontSize: 11.5),
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lokasi dinas luar wajib diisi';
                  }
                  if (val.trim().length < 3) {
                    return 'Nama tempat minimal 3 karakter';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Simpan & Lanjutkan', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }

  /// Menampilkan modal dialog pratinjau foto selfie dan konfirmasi presensi
  Future<dynamic> _showSelfieConfirmationDialog({
    required BuildContext context,
    required AttendanceProvider attend,
    required File photo,
    required String actionType,
    required bool isForcedOut,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDinas = attend.isDinasLuar;
    final currentLokasi = _lokasiController.text.isNotEmpty
        ? _lokasiController.text
        : (attend.lokasiDinasLuar.isNotEmpty && attend.lokasiDinasLuar != 'Penugasan Luar / DUDI'
            ? attend.lokasiDinasLuar
            : '');
    final lokasiConfirmController = TextEditingController(text: currentLokasi);
    final formKey = GlobalKey<FormState>();

    Color typeColor = const Color(0xFF10B981);
    if (actionType.toLowerCase().contains('pulang')) {
      typeColor = const Color(0xFFF59E0B);
    }

    return showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmittingLocal = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      actionType.toLowerCase().contains('pulang')
                          ? Icons.logout_rounded
                          : Icons.login_rounded,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Konfirmasi Presensi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Presensi $actionType • CompreFace AI',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pratinjau Foto Selfie
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              photo,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      '640×640 Siap AI',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status GPS Geofencing
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isDinas ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDinas ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDinas ? Icons.business_center_rounded : Icons.location_on_rounded,
                              size: 16,
                              color: isDinas ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isDinas
                                    ? 'Status: Dinas Luar Sekolah'
                                    : (attend.isWithinRadius
                                        ? 'GPS: Berada di Dalam Radius Sekolah'
                                        : 'GPS: ${attend.distanceToSchool?.toStringAsFixed(0) ?? "?"}m dari sekolah'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDinas ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Input Lokasi Dinas Luar (jika dinas luar)
                      if (isDinas) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lokasiConfirmController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            labelText: 'Tempat / Lokasi Dinas Luar *',
                            labelStyle: const TextStyle(fontSize: 11.5),
                            hintText: 'Misal: PT Telkom, Kantor Cabang, DUDI',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Lokasi dinas luar wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    // Tombol Ambil Ulang Foto
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Foto Ulang', style: TextStyle(fontSize: 12)),
                        onPressed: isSubmittingLocal
                            ? null
                            : () => Navigator.pop(ctx, 'retake'),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tombol Kirim Presensi Sekarang
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        icon: isSubmittingLocal
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          isSubmittingLocal ? 'Mengirim...' : 'Kirim Presensi',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isSubmittingLocal
                            ? null
                            : () async {
                                if (isDinas && formKey.currentState?.validate() != true) {
                                  return;
                                }

                                final finalLokasi = lokasiConfirmController.text.trim();
                                if (isDinas && finalLokasi.isNotEmpty) {
                                  attend.setLokasiDinasLuar(finalLokasi);
                                  _lokasiController.text = finalLokasi;
                                }

                                setModalState(() {
                                  isSubmittingLocal = true;
                                });

                                try {
                                  final result = await attend.submitProcessedSelfie(
                                    photo: photo,
                                    customLokasiDinasLuar: isDinas ? finalLokasi : null,
                                    isForcedOut: isForcedOut,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, result);
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isSubmittingLocal = false;
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, e);
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSelfieAttendance(BuildContext context, AttendanceProvider attend) async {
    // 0. Cegah presensi jika sudah selesai presensi hari ini
    if (attend.isCompletedToday || attend.hasClockedOut) {
      _showAttendanceCompletedDialog(context);
      return;
    }

    final bool isForcedOut = attend.presensiType.toLowerCase().contains('pulang');
    final String actionType = isForcedOut ? 'Pulang' : 'Masuk';
    bool bypassGps = false;

    // 1. Jika di luar radius dan belum dinas luar, tanyakan opsi dengan jelas & minta input lokasi jika dinas
    if (!attend.isDinasLuar && !attend.isWithinRadius && attend.distanceToSchool != null) {
      final school = attend.schoolSetting;
      final distStr = attend.distanceToSchool!.toStringAsFixed(0);

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Color(0xFFEAB308), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Di Luar Radius Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jarak GPS Anda saat ini $distStr meter dari ${school.name}.\nRadius toleransi sekolah adalah ${school.radiusMeters.toStringAsFixed(0)} meter.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih opsi untuk melanjutkan presensi selfie:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () => Navigator.pop(ctx, 'dinas'),
              child: const Text('Aktifkan Dinas Luar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('Tetap Buka Kamera'),
            ),
          ],
        ),
      );

      if (result == null || result == 'cancel') return;
      if (result == 'force') {
        bypassGps = true;
      } else if (result == 'dinas') {
        if (!context.mounted) return;
        final lokasi = await _promptLokasiDinasLuar(
          context,
          initialValue: _lokasiController.text,
        );
        if (lokasi == null || lokasi.trim().isEmpty) {
          return;
        }
        attend.setDinasLuar(true, lokasi: lokasi);
        _lokasiController.text = lokasi;
      }
    } else if (attend.isDinasLuar) {
      // Jika sudah dalam status dinas luar tetapi lokasi masih kosong, minta input terlebih dahulu
      if (_lokasiController.text.trim().isEmpty && attend.lokasiDinasLuar.trim().isEmpty) {
        final lokasi = await _promptLokasiDinasLuar(context);
        if (lokasi == null || lokasi.trim().isEmpty) return;
        attend.setDinasLuar(true, lokasi: lokasi);
        _lokasiController.text = lokasi;
      }
    }

    // 2. Loop Capture Foto & Konfirmasi (bisa foto ulang jika hasil buram/kurang cocok)
    while (context.mounted) {
      try {
        final File? photo = await attend.pickAndProcessSelfiePhoto(bypassGpsCheck: bypassGps);
        if (photo == null || !context.mounted) {
          // Pengguna membatalkan kamera
          return;
        }

        final dynamic confirmResult = await _showSelfieConfirmationDialog(
          context: context,
          attend: attend,
          photo: photo,
          actionType: actionType,
          isForcedOut: isForcedOut,
        );

        if (confirmResult == 'retake') {
          // Ambil ulang foto (loop berlanjut)
          continue;
        } else if (confirmResult is SelfieAttendanceResult) {
          if (context.mounted) {
            _showSuccessDialog(context, confirmResult);
          }
          return;
        } else if (confirmResult is Exception) {
          throw confirmResult;
        } else {
          // Pengguna membatalkan dialog konfirmasi
          return;
        }
      } on AttendanceException catch (e) {
        if (!context.mounted) return;

        if (e.isCompleted) {
          _showAttendanceCompletedDialog(context);
        } else if (e.isFaceMismatch) {
          _showFaceMismatchDialog(context, attend, e.message);
        } else if (e.isOutsideRadius) {
          _showOutsideRadiusDialog(context, e.message);
        } else if (e.isRateLimit) {
          _showRateLimitDialog(context, e.message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melakukan presensi: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
  }

  Future<void> _handleRegisterMasterFace(BuildContext context, AttendanceProvider attend) async {
    try {
      final success = await attend.registerMasterFace();
      if (success && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 8),
                Text('Wajah Master Berhasil!', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: const Text(
              'Foto master Anda telah diperbarui di CompreFace AI database sekolah. Sekarang silakan coba presensi selfie kembali.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, Mengerti'),
              ),
            ],
          ),
        );
      }
    } on AttendanceException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pendaftaran gagal: ${e.message}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==================== HANDLER PRESENSI TAP KARTU NFC ====================
  Future<void> _handleNfcAttendance(BuildContext context, AttendanceProvider attend) async {
    // 0. Cegah tap kartu jika sudah presensi hari ini
    if (attend.isCompletedToday || attend.hasClockedOut) {
      _showAttendanceCompletedDialog(context);
      return;
    }

    // 1. Jika di luar radius dan belum dinas luar, tanyakan opsi dengan jelas
    if (!attend.isDinasLuar && !attend.isWithinRadius && attend.distanceToSchool != null) {
      final school = attend.schoolSetting;
      final distStr = attend.distanceToSchool!.toStringAsFixed(0);

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Color(0xFFEAB308), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Di Luar Radius Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jarak GPS Anda saat ini $distStr meter dari ${school.name}.\nRadius toleransi sekolah adalah ${school.radiusMeters.toStringAsFixed(0)} meter.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih opsi untuk melanjutkan presensi tap kartu NFC:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () => Navigator.pop(ctx, 'dinas'),
              child: const Text('Aktifkan Dinas Luar'),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) return;
      if (result == 'dinas') {
        if (!context.mounted) return;
        final lokasi = await _promptLokasiDinasLuar(
          context,
          initialValue: _lokasiController.text,
        );
        if (lokasi == null || lokasi.trim().isEmpty) return;
        attend.setDinasLuar(true, lokasi: lokasi);
        _lokasiController.text = lokasi;
      }
    }

    if (!context.mounted) return;
    NfcAttendanceSheet.show(context);
  }

  // ==================== HANDLER PRESENSI BLUETOOTH BLE WEMOS ====================
  Future<void> _handleBluetoothAttendance(BuildContext context, AttendanceProvider attend) async {
    // 0. Cegah presensi jika sudah selesai presensi hari ini
    if (attend.isCompletedToday || attend.hasClockedOut) {
      _showAttendanceCompletedDialog(context);
      return;
    }

    // 1. Jika di luar radius dan belum dinas luar, tanyakan opsi dengan jelas
    if (!attend.isDinasLuar && !attend.isWithinRadius && attend.distanceToSchool != null) {
      final school = attend.schoolSetting;
      final distStr = attend.distanceToSchool!.toStringAsFixed(0);

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Color(0xFFEAB308), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Di Luar Radius Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jarak GPS Anda saat ini $distStr meter dari ${school.name}.\nRadius toleransi sekolah adalah ${school.radiusMeters.toStringAsFixed(0)} meter.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih opsi untuk melanjutkan presensi Bluetooth Wemos:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () => Navigator.pop(ctx, 'dinas'),
              child: const Text('Aktifkan Dinas Luar'),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) return;
      if (result == 'dinas') {
        if (!context.mounted) return;
        final lokasi = await _promptLokasiDinasLuar(
          context,
          initialValue: _lokasiController.text,
        );
        if (lokasi == null || lokasi.trim().isEmpty) return;
        attend.setDinasLuar(true, lokasi: lokasi);
        _lokasiController.text = lokasi;
      }
    }

    if (!context.mounted) return;
    BluetoothAttendanceSheet.show(context);
  }

  // ==================== DIALOG SUKSES BER-WATERMARK ====================
  void _showSuccessDialog(BuildContext context, SelfieAttendanceResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon Sukses Animatif
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF10B981),
                size: 46,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Presensi ${result.presensiType} Berhasil!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              result.message ?? 'Data kehadiran Anda telah tercatat sah di server.',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Rincian Jam & Nilai Kemiripan AI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Waktu Presensi', style: TextStyle(fontSize: 12)),
                      Text(
                        result.waktu ?? 'Tercatat',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (result.similarity != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kecocokan AI (CompreFace)', style: TextStyle(fontSize: 12)),
                        Text(
                          '${result.similarity!.toStringAsFixed(1)}% (≥90%)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Foto Ber-Watermark jika ada
            if (result.photoWatermarkUrl != null && result.photoWatermarkUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  result.photoWatermarkUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG EDUKASI WAJAH TIDAK COCOK (<90%) ====================
  void _showFaceMismatchDialog(BuildContext context, AttendanceProvider attend, String message) {
    final masterUrl = attend.currentUser?.masterPhotoUrl ??
        'https://baknusattend.smkbn666.sch.id/storage/face-references/01KQRGKHGZDZDG082EKD7B80C1.jpg';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.face_retouching_off_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Wajah Tidak Cocok',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),

              // Preview Foto Master yang ada di database server
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        masterUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, size: 48, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto Master di Database',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI membandingkan selfie Anda dengan foto di atas (threshold ≥90%).',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tips agar Presensi Sukses:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('• Hadapkan wajah tegak lurus ke kamera depan (jarak 30-50 cm).',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
                    Text('• Pastikan pencahayaan terang merata (hindari backlight).',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
                    Text('• Buka masker, kacamata, atau topi.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_a_photo_rounded, size: 16),
            label: const Text('Perbarui Master Wajah'),
            onPressed: () {
              Navigator.pop(ctx);
              _handleRegisterMasterFace(context, attend);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG DI LUAR RADIUS ====================
  void _showOutsideRadiusDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Color(0xFFEAB308), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Di Luar Radius Sekolah',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () async {
              Navigator.pop(ctx);
              final lokasi = await _promptLokasiDinasLuar(
                context,
                initialValue: _lokasiController.text,
              );
              if (lokasi != null && lokasi.trim().isNotEmpty && context.mounted) {
                context.read<AttendanceProvider>().setDinasLuar(true, lokasi: lokasi);
                _lokasiController.text = lokasi;
              }
            },
            child: const Text('Aktifkan Dinas Luar'),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG RATE LIMIT ANTI-SPAM ====================
  void _showRateLimitDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 26),
            SizedBox(width: 10),
            Text('Mohon Tunggu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG PRESENSI TELAH SELESAI ====================
  void _showAttendanceCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Presensi Hari Ini Selesai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Anda telah menyelesaikan seluruh presensi (Masuk & Pulang) hari ini.\n\nFasilitas presensi mandiri (Selfie & Tap NFC) sudah ditutup dan tidak dapat digunakan lagi.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, Mengerti'),
          ),
        ],
      ),
    );
  }
}
