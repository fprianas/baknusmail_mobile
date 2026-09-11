import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/attendance_model.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/wemos_ble_service.dart';
import '../../providers/attendance_provider.dart';

enum BluetoothAttendanceStep {
  requestChallenge,
  connectDevice,
  exchangeBle,
  verifyServer,
  completed,
  error,
}

class BluetoothAttendanceSheet extends StatefulWidget {
  const BluetoothAttendanceSheet({super.key});

  /// Menampilkan modal bottom sheet proses presensi Bluetooth BLE
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BluetoothAttendanceSheet(),
    );
  }

  @override
  State<BluetoothAttendanceSheet> createState() => _BluetoothAttendanceSheetState();
}

class _BluetoothAttendanceSheetState extends State<BluetoothAttendanceSheet>
    with SingleTickerProviderStateMixin {
  final WemosBleService _bleService = WemosBleService();

  BluetoothAttendanceStep _currentStep = BluetoothAttendanceStep.requestChallenge;
  BluetoothAttendanceStep? _failedStep;
  String _statusMessage = 'Menyiapkan proses presensi Bluetooth...';
  String? _errorMessage;
  String? _deviceNameFound;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Mulai proses handshake Bluetooth otomatis begitu sheet dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBluetoothAttendanceProcess();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Alur lengkap: Challenge -> Scan & Connect BLE -> Write/Read Signature -> Verify Server
  Future<void> _startBluetoothAttendanceProcess() async {
    if (!mounted) return;

    setState(() {
      _currentStep = BluetoothAttendanceStep.requestChallenge;
      _statusMessage = 'Meminta token keamanan ke server...';
      _errorMessage = null;
      _deviceNameFound = null;
    });

    final attendProvider = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      // 0. Pengecekan Izin & Kondisi Hardware (Bluetooth & GPS)
      final isBtOn = await _bleService.isBluetoothEnabled();
      if (!isBtOn) {
        throw const WemosBleException(
          'Bluetooth pada smartphone Anda sedang nonaktif. Mohon aktifkan Bluetooth terlebih dahulu.',
          isBluetoothOff: true,
        );
      }

      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        throw AttendanceException(
          message: 'Layanan lokasi/GPS pada smartphone Anda nonaktif. Mohon aktifkan GPS terlebih dahulu.',
        );
      }

      // LANGKAH 1: Meminta token keamanan ke server
      final challengeResponse = await attendProvider.getBluetoothChallenge();
      final challengeStartTime = DateTime.now();

      if (!mounted) return;
      setState(() {
        _currentStep = BluetoothAttendanceStep.connectDevice;
        _statusMessage = 'Mencari sinyal Bluetooth Wemos di sekitar...';
      });

      // LANGKAH 2 & 3: Mencari sinyal, terhubung, dan verifikasi ke alat Wemos
      final bleResult = await _bleService.exchangeChallengeResponse(
        challengeCode: challengeResponse.challengeCode,
        userName: challengeResponse.userName,
        scanTimeout: const Duration(seconds: 10),
        onStatusChanged: (msg) {
          if (!mounted) return;
          setState(() {
            if (msg.contains('Menghubungkan') || msg.contains('Membaca')) {
              _currentStep = BluetoothAttendanceStep.connectDevice;
              _statusMessage = 'Terhubung! Memverifikasi ke alat...';
            } else if (msg.contains('Mengirim') || msg.contains('signature')) {
              _currentStep = BluetoothAttendanceStep.exchangeBle;
              _statusMessage = 'Terhubung! Memverifikasi ke alat...';
            } else {
              _statusMessage = msg;
            }
          });
        },
      );

      _deviceNameFound = bleResult.deviceName;

      // Cek Token Kedaluwarsa (> 60 detik)
      final elapsed = DateTime.now().difference(challengeStartTime).inSeconds;
      final maxTtl = challengeResponse.expiresIn > 0 ? challengeResponse.expiresIn : 60;
      if (elapsed > maxTtl) {
        throw AttendanceException(
          message: 'Token keamanan telah kedaluwarsa (> $maxTtl detik). Silakan coba presensi kembali.',
          statusCode: 422,
        );
      }

      if (!mounted) return;
      setState(() {
        _currentStep = BluetoothAttendanceStep.verifyServer;
        _statusMessage = 'Mengirim konfirmasi presensi ke server...';
      });

      // LANGKAH 4: Mengirim konfirmasi presensi (Signature + Device ID + GPS) ke server
      final result = await attendProvider.submitBluetoothAttendance(
        deviceId: bleResult.deviceId,
        challengeCode: challengeResponse.challengeCode,
        signature: bleResult.signature,
      );

      // LANGKAH 5 (SELESAI): Notifikasi sukses dengan suara/vibrasi haptic
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      setState(() {
        _currentStep = BluetoothAttendanceStep.completed;
        _statusMessage = 'Presensi Berhasil!';
      });

      // Tampilkan notifikasi dialog sukses
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _showSuccessDialog(result);
    } catch (e) {
      HapticFeedback.vibrate();
      debugPrint('[BLE_ATTENDANCE_ERROR] Gagal presensi BLE: $e');
      if (!mounted) return;

      String errorMsg = e.toString();
      if (e is AttendanceException) {
        errorMsg = e.message;
      } else if (e is WemosBleException) {
        errorMsg = e.message;
      }

      setState(() {
        _failedStep = _currentStep;
        _currentStep = BluetoothAttendanceStep.error;
        _errorMessage = errorMsg;
        _statusMessage = 'Presensi Gagal di tahap ${_stepToTitle(_failedStep)}';
      });
    }
  }

  String _stepToTitle(BluetoothAttendanceStep? step) {
    switch (step) {
      case BluetoothAttendanceStep.requestChallenge:
        return 'Permintaan Token Server';
      case BluetoothAttendanceStep.connectDevice:
        return 'Koneksi ke Alat Wemos';
      case BluetoothAttendanceStep.exchangeBle:
        return 'Pertukaran Data (Handshake)';
      case BluetoothAttendanceStep.verifyServer:
        return 'Verifikasi Server';
      default:
        return 'Sistem';
    }
  }

  void _showSuccessDialog(BluetoothAttendanceResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Presensi Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.message,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Jenis Presensi', result.tipe, isDark),
                    const Divider(height: 12),
                    _buildInfoRow('Status', result.statusKehadiran, isDark, valueColor: const Color(0xFF059669)),
                    if (result.deviceName != null && result.deviceName!.isNotEmpty) ...[
                      const Divider(height: 12),
                      _buildInfoRow('Lokasi Alat', result.deviceName!, isDark),
                    ],
                    if (result.waktu != null && result.waktu!.isNotEmpty) ...[
                      const Divider(height: 12),
                      _buildInfoRow('Waktu', result.waktu!, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop(); // Tutup dialog
                  Navigator.of(context).pop(); // Tutup sheet
                },
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bluetooth_searching_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Presensi Bluetooth Wemos',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Hardware BLE Offline • Challenge-Response',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Radar Pulse Icon
              _buildRadarAnimation(isDark),

              const SizedBox(height: 20),

              // Status Message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _statusMessage,
                  key: ValueKey<String>(_statusMessage),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _currentStep == BluetoothAttendanceStep.error
                        ? const Color(0xFFEF4444)
                        : _currentStep == BluetoothAttendanceStep.completed
                            ? const Color(0xFF059669)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),

              if (_deviceNameFound != null && _currentStep != BluetoothAttendanceStep.error) ...[
                const SizedBox(height: 6),
                Text(
                  'Terhubung ke: $_deviceNameFound',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Step Indicator Bar
              _buildStepIndicators(isDark),

              // Error Message Box jika ada
              if (_currentStep == BluetoothAttendanceStep.error && _errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Pesan Error:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _errorMessage ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pesan error berhasil disalin!')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 14, color: Color(0xFFEF4444)),
                                  SizedBox(width: 4),
                                  Text('Salin', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _startBluetoothAttendanceProcess,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarAnimation(bool isDark) {
    Color pulseColor = const Color(0xFF2563EB);
    IconData centerIcon = Icons.bluetooth_audio_rounded;

    if (_currentStep == BluetoothAttendanceStep.error) {
      pulseColor = const Color(0xFFEF4444);
      centerIcon = Icons.bluetooth_disabled_rounded;
    } else if (_currentStep == BluetoothAttendanceStep.completed) {
      pulseColor = const Color(0xFF059669);
      centerIcon = Icons.check_circle_rounded;
    }

    return ScaleTransition(
      scale: _currentStep == BluetoothAttendanceStep.completed ||
              _currentStep == BluetoothAttendanceStep.error
          ? const AlwaysStoppedAnimation(1.0)
          : _pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pulseColor.withValues(alpha: 0.12),
          border: Border.all(
            color: pulseColor.withValues(alpha: 0.35),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: pulseColor.withValues(alpha: 0.20),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pulseColor,
              boxShadow: [
                BoxShadow(
                  color: pulseColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(centerIcon, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicators(bool isDark) {
    final steps = [
      {'label': '1. Token', 'step': BluetoothAttendanceStep.requestChallenge},
      {'label': '2. Hubungkan', 'step': BluetoothAttendanceStep.connectDevice},
      {'label': '3. Handshake', 'step': BluetoothAttendanceStep.exchangeBle},
      {'label': '4. Verifikasi', 'step': BluetoothAttendanceStep.verifyServer},
    ];

    int activeIndex = 0;
    final checkStep = _currentStep == BluetoothAttendanceStep.error ? (_failedStep ?? _currentStep) : _currentStep;
    if (checkStep == BluetoothAttendanceStep.requestChallenge) activeIndex = 0;
    if (checkStep == BluetoothAttendanceStep.connectDevice) activeIndex = 1;
    if (checkStep == BluetoothAttendanceStep.exchangeBle) activeIndex = 2;
    if (checkStep == BluetoothAttendanceStep.verifyServer) activeIndex = 3;
    if (checkStep == BluetoothAttendanceStep.completed) activeIndex = 4;

    return Row(
      children: List.generate(steps.length, (index) {
        final isDone = activeIndex > index;
        final isCurrent = activeIndex == index && _currentStep != BluetoothAttendanceStep.error;
        final isFailed = _currentStep == BluetoothAttendanceStep.error && activeIndex == index;

        Color dotColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
        if (isDone) dotColor = const Color(0xFF059669);
        if (isCurrent) dotColor = const Color(0xFF2563EB);
        if (isFailed) dotColor = const Color(0xFFEF4444);

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: index == 0
                          ? Colors.transparent
                          : (isDone ? const Color(0xFF059669) : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 10)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: index == steps.length - 1
                          ? Colors.transparent
                          : (isDone && activeIndex > index + 1
                              ? const Color(0xFF059669)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[index]['label'] as String,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? const Color(0xFF2563EB)
                      : (isDone
                          ? const Color(0xFF059669)
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
