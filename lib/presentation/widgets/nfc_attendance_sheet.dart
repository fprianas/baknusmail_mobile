import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/attendance_model.dart';
import '../../data/services/attendance_service.dart';
import '../../providers/attendance_provider.dart';

class NfcAttendanceSheet extends StatefulWidget {
  const NfcAttendanceSheet({super.key});

  /// Helper untuk menampilkan NFC attendance bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NfcAttendanceSheet(),
    );
  }

  @override
  State<NfcAttendanceSheet> createState() => _NfcAttendanceSheetState();
}

class _NfcAttendanceSheetState extends State<NfcAttendanceSheet>
    with SingleTickerProviderStateMixin {
  bool _isCheckingAvailability = true;
  bool _isNfcAvailable = false;
  bool _isScanning = false;
  bool _isProcessing = false;
  String? _detectedUid;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initNfc();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    _stopNfcSession();
    super.dispose();
  }

  Future<void> _stopNfcSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  Future<void> _initNfc() async {
    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!mounted) return;

      setState(() {
        _isCheckingAvailability = false;
        _isNfcAvailable = isAvailable;
      });

      if (isAvailable) {
        _startScanSession();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingAvailability = false;
        _isNfcAvailable = false;
        _errorMessage = 'Gagal memeriksa sensor NFC: $e';
      });
    }
  }

  void _startScanSession() {
    setState(() {
      _isScanning = true;
      _isProcessing = false;
      _detectedUid = null;
      _errorMessage = null;
    });

    // Timeout otomatis 35 detik
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 35), () {
      if (mounted && _isScanning && !_isProcessing) {
        _stopNfcSession();
        setState(() {
          _isScanning = false;
          _errorMessage = 'Waktu pemindaian NFC habis. Silakan coba kembali.';
        });
      }
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        final uid = _extractUid(tag);
        if (uid == null || uid.isEmpty) {
          debugPrint('NFC Tag terdeteksi namun UID tidak dapat diekstrak');
          return;
        }

        // Hentikan sesi scan NFC
        await _stopNfcSession();
        _timeoutTimer?.cancel();

        // Getar haptic menandakan kartu terdeteksi
        HapticFeedback.mediumImpact();

        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _isProcessing = true;
          _detectedUid = uid;
        });

        // Kirim ke server via AttendanceProvider
        await _submitNfcAttendance(uid);
      },
      onError: (NfcError error) async {
        debugPrint('NFC Session Error: ${error.message}');
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  /// Ekstraksi UID Kartu NFC dari berbagai format tag (Mifare, NfcA, IsoDep, dll)
  String? _extractUid(NfcTag tag) {
    List<int>? identifier;

    final nfca = NfcA.from(tag);
    if (nfca != null) identifier = nfca.identifier;

    if (identifier == null) {
      final mifare = MifareClassic.from(tag);
      if (mifare != null) identifier = mifare.identifier;
    }

    if (identifier == null) {
      final mifareUl = MifareUltralight.from(tag);
      if (mifareUl != null) identifier = mifareUl.identifier;
    }

    if (identifier == null) {
      final isodep = IsoDep.from(tag);
      if (isodep != null) identifier = isodep.identifier;
    }

    if (identifier == null) {
      final nfcb = NfcB.from(tag);
      if (nfcb != null) identifier = nfcb.identifier;
    }

    if (identifier == null) {
      final nfcf = NfcF.from(tag);
      if (nfcf != null) identifier = nfcf.identifier;
    }

    if (identifier == null) {
      final nfcv = NfcV.from(tag);
      if (nfcv != null) identifier = nfcv.identifier;
    }

    // Fallback pemeriksaan raw Map tag.data
    if (identifier == null) {
      final map = tag.data;
      for (final key in [
        'nfca',
        'mifareclassic',
        'mifareultralight',
        'isodep',
        'nfcb',
        'nfcf',
        'nfcv',
        'mifare'
      ]) {
        final sub = map[key];
        if (sub is Map && sub['identifier'] is List) {
          identifier = (sub['identifier'] as List).whereType<int>().toList();
          break;
        }
      }
    }

    if (identifier != null && identifier.isNotEmpty) {
      return identifier
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
    }

    return null;
  }

  Future<void> _submitNfcAttendance(String uid) async {
    final attend = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      final result = await attend.submitCardTap(rfidUid: uid);

      if (!mounted) return;
      // Tutup BottomSheet
      Navigator.pop(context);

      // Tampilkan Pop-Up Sukses
      _showSuccessDialog(context, result);
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });

      if (e.isRouteNotFound) {
        _showRouteNotFoundDialog(context, e.message);
      } else if (e.isCompleted) {
        _showAttendanceCompletedDialog(context, e.message);
      } else if (e.statusCode == 422) {
        _showMismatchCardDialog(context, e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Terjadi kesalahan sistem: $e';
      });
    }
  }

  // ==================== DIALOG SUKSES ====================
  void _showSuccessDialog(BuildContext context, CardTapAttendanceResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presensi ${result.tipe} (Tap NFC) Berhasil!',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              result.message,
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
                        result.waktu ?? result.jam ?? 'Tercatat',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Kehadiran', style: TextStyle(fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.statusKehadiran,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (result.rfidUid != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UID Kartu NFC', style: TextStyle(fontSize: 12)),
                        Text(
                          result.rfidUid!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
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
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG PERINGATAN KARTU ====================
  void _showMismatchCardDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.credit_card_off_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Validasi Kartu Gagal',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG ROUTE BELUM AKTIF ====================
  void _showRouteNotFoundDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Layanan Belum Aktif di Server',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF92400E), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aplikasi Flutter siap, silakan daftarkan endpoint POST /api/presence/card-tap di backend Laravel.',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG PRESENSI SUDAH SELESAI ====================
  void _showAttendanceCompletedDialog(BuildContext context, String message) {
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
                'Presensi Selesai',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Bar
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nfc_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Presensi Tap Kartu NFC',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gunakan Kartu Pelajar, Pegawai, atau e-KTP fisik yang terdaftar di sekolah',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Body Area Sesuai Status
            if (_isCheckingAvailability) ...[
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              const Text('Memeriksa ketersediaan NFC...'),
            ] else if (!_isNfcAvailable) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.nfc_rounded, color: Color(0xFFDC2626), size: 48),
                    SizedBox(height: 10),
                    Text(
                      'Perangkat ini tidak mendukung fitur NFC',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Pastikan smartphone Anda memiliki modul NFC dan fitur NFC telah diaktifkan di Pengaturan Perangkat.',
                      style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_isProcessing) ...[
              // State Processing
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'Kartu Terdeteksi! (UID: ${_detectedUid ?? '...'})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Memverifikasi kehadiran & lokasi GPS ke server...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // State Scanning Interaktif
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2563EB).withValues(alpha: 0.25),
                        const Color(0xFF3B82F6).withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x552563EB),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.contactless_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dekatkan Kartu ke Belakang Ponsel...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tempelkan kartu RFID/NFC di sekitar sensor belakang kamera hingga bergetar.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tombol Aksi Bawah
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _stopNfcSession();
                      Navigator.pop(context);
                    },
                    child: const Text('Batal'),
                  ),
                ),
                if (_errorMessage != null && _isNfcAvailable) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Pindai Ulang'),
                      onPressed: _startScanSession,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
