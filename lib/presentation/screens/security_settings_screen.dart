import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/security_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/pin_setup_dialog.dart';
import 'app_lock_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  Future<void> _handleToggleAppLock(bool enable) async {
    final security = context.read<SecurityProvider>();

    if (enable) {
      // Jika belum ada PIN, minta buat PIN 6 digit terlebih dahulu
      if (!security.hasPin) {
        final newPin = await PinSetupDialog.show(
          context,
          title: 'Buat PIN 6 Digit',
          subtitle: 'Tentukan 6 digit PIN utama untuk mengamankan aplikasi.',
        );

        if (newPin != null && mounted) {
          await security.setPin(newPin);
          await security.setAppLockEnabled(true);

          // Jika perangkat mendukung biometrik, tawarkan langsung
          if (security.canCheckBiometrics) {
            _offerBiometricQuickSetup();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kunci aplikasi berhasil diaktifkan dengan PIN 6 digit.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        await security.setAppLockEnabled(true);
      }
    } else {
      // Konfirmasi sebelum menonaktifkan
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nonaktifkan Kunci Aplikasi?'),
          content: const Text(
            'Siapa saja yang memegang HP Anda akan dapat langsung membuka BaknusMail tanpa verifikasi PIN atau sidik jari.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await security.clearPin();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunci aplikasi telah dinonaktifkan.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleChangePin() async {
    final security = context.read<SecurityProvider>();
    final newPin = await PinSetupDialog.show(
      context,
      title: 'Ganti PIN 6 Digit',
      subtitle: 'Tentukan 6 digit PIN baru untuk aplikasi Anda.',
    );

    if (newPin != null && mounted) {
      await security.setPin(newPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN 6 digit berhasil diperbarui!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleToggleBiometric(bool enable) async {
    final security = context.read<SecurityProvider>();

    if (enable) {
      // Verifikasi sensor biometrik sebelum menyalakan
      final result = await security.authenticateWithBiometrics(
        reason: 'Verifikasi identitas Anda untuk mengaktifkan kunci biometrik',
      );

      if (result.success && mounted) {
        await security.setBiometricEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${security.biometricLabel} berhasil diaktifkan.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        if (result.isNotEnrolled) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Biometrik Belum Terdaftar'),
                ],
              ),
              content: const Text(
                'Sensor sidik jari atau wajah belum didaftarkan di sistem Android HP Anda.\n\n'
                'Silakan buka menu Pengaturan HP -> Keamanan & Kunci Layar -> Sidik Jari / Wajah, lalu daftarkan sidik jari Anda terlebih dahulu.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Verifikasi biometrik dibatalkan atau gagal.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      await security.setBiometricEnabled(false);
    }
  }

  void _offerBiometricQuickSetup() {
    final security = context.read<SecurityProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Aktifkan ${security.biometricLabel}?'),
          ],
        ),
        content: Text(
          'Perangkat Anda mendukung ${security.biometricLabel}. Apakah Anda ingin menggunakannya untuk membuka aplikasi lebih cepat tanpa mengetik PIN?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleToggleBiometric(true);
            },
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
  }

  String _getTimeoutLabel(int seconds) {
    switch (seconds) {
      case 0:
        return 'Segera (saat aplikasi ditutup)';
      case 30:
        return 'Setelah 30 Detik di latar belakang';
      case 60:
        return 'Setelah 1 Menit di latar belakang';
      case 300:
        return 'Setelah 5 Menit di latar belakang';
      default:
        return '$seconds detik';
    }
  }

  void _showTimeoutPicker(BuildContext context, int currentSeconds) {
    final security = context.read<SecurityProvider>();
    final options = [
      {'label': 'Segera (saat keluar aplikasi)', 'seconds': 0},
      {'label': 'Setelah 30 Detik', 'seconds': 30},
      {'label': 'Setelah 1 Menit', 'seconds': 60},
      {'label': 'Setelah 5 Menit', 'seconds': 300},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Kunci Otomatis Setelah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...options.map((opt) {
                final isSelected = opt['seconds'] == currentSeconds;
                return ListTile(
                  title: Text(opt['label'] as String),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    security.setLockTimeoutSeconds(opt['seconds'] as int);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _getChatTimeoutLabel(int seconds) {
    switch (seconds) {
      case 300:
        return '5 Menit setelah chat diminimalkan';
      case 600:
        return '10 Menit (Rekomendasi)';
      case 900:
        return '15 Menit';
      case 1800:
        return '30 Menit';
      case 86400:
        return 'Selama berada di halaman chat';
      default:
        return '${seconds ~/ 60} Menit';
    }
  }

  void _showChatTimeoutPicker(BuildContext context, int currentSeconds) {
    final security = context.read<SecurityProvider>();
    final options = [
      {'label': '5 Menit', 'seconds': 300},
      {'label': '10 Menit (Rekomendasi)', 'seconds': 600},
      {'label': '15 Menit', 'seconds': 900},
      {'label': '30 Menit', 'seconds': 1800},
      {'label': 'Selama berada di halaman chat', 'seconds': 86400},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Batas Toleransi Obrolan BaknusChat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...options.map((opt) {
                final isSelected = opt['seconds'] == currentSeconds;
                return ListTile(
                  title: Text(opt['label'] as String),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    security.setChatGraceTimeoutSeconds(opt['seconds'] as int);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final security = context.watch<SecurityProvider>();
    final isProtected = security.isAppLockEnabled && security.hasPin;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Keamanan & Kunci Aplikasi'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Status Hero Banner Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isProtected
                      ? [
                          const Color(0xFF059669).withValues(alpha: isDark ? 0.35 : 0.15),
                          const Color(0xFF0284C7).withValues(alpha: isDark ? 0.35 : 0.15),
                        ]
                      : [
                          (isDark ? AppColors.darkSurface : Colors.white),
                          (isDark ? AppColors.darkSurfaceElevated : Colors.white),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isProtected
                      ? const Color(0xFF059669).withValues(alpha: 0.4)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isProtected
                          ? const Color(0xFF059669).withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProtected ? Icons.verified_user_rounded : Icons.shield_outlined,
                      color: isProtected ? const Color(0xFF059669) : AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProtected ? 'Aplikasi Terlindungi' : 'Kunci Aplikasi Nonaktif',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isProtected ? const Color(0xFF059669) : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isProtected
                              ? 'Aplikasi dikunci dengan ${security.isBiometricEnabled ? "PIN & ${security.biometricLabel}" : "PIN 6 Digit"}.'
                              : 'Aktifkan kunci untuk mengamankan email, presensi, & obrolan Anda.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Sakelar Kunci Utama
            _buildSectionHeader('Proteksi Utama', isDark),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: SwitchListTile(
                value: security.isAppLockEnabled,
                onChanged: _handleToggleAppLock,
                title: const Text(
                  'Kunci Aplikasi (App Lock)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  'Meminta verifikasi PIN atau biometrik saat aplikasi dibuka',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                activeThumbColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 22),

            // Opsi Metode Keamanan (hanya aktif jika App Lock aktif)
            if (security.isAppLockEnabled) ...[
              _buildSectionHeader('Pilihan Metode Keamanan', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    // Ubah PIN 6 Digit
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pin_rounded, color: AppColors.primary, size: 22),
                      ),
                      title: const Text('PIN 6 Digit', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'PIN master terkonfigurasi • Tekan untuk ganti PIN',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _handleChangePin,
                    ),

                    const Divider(height: 1),

                    // Kunci Biometrik (Fingerprint / Face ID)
                    SwitchListTile(
                      value: security.isBiometricEnabled,
                      onChanged: security.canCheckBiometrics ? _handleToggleBiometric : null,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (security.canCheckBiometrics
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: security.canCheckBiometrics
                              ? const Color(0xFF0284C7)
                              : Colors.grey,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        security.biometricLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        security.canCheckBiometrics
                            ? 'Buka kunci instan menggunakan sensor biometrik HP'
                            : 'Sensor biometrik tidak tersedia atau belum didaftarkan di HP ini',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      activeThumbColor: const Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Waktu Kunci Otomatis
              _buildSectionHeader('Waktu Penguncian Otomatis', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  title: const Text('Kunci Otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _getTimeoutLabel(security.lockTimeoutSeconds),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                  onTap: () => _showTimeoutPicker(context, security.lockTimeoutSeconds),
                ),
              ),
              const SizedBox(height: 22),

              // Toleransi Khusus BaknusChat
              _buildSectionHeader('Toleransi Khusus BaknusChat', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: security.isChatGraceEnabled,
                      onChanged: (val) => security.setChatGraceEnabled(val),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Toleransi Obrolan Aktif',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Jangan kunci aplikasi saat sedang aktif di ruang chat BaknusChat sehingga tidak terganggu tiap kali ada notif masuk',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      activeThumbColor: const Color(0xFF10B981),
                    ),
                    if (security.isChatGraceEnabled) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.timer_outlined, color: Color(0xFF10B981), size: 22),
                        ),
                        title: const Text(
                          'Batas Toleransi Obrolan',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          _getChatTimeoutLabel(security.chatGraceTimeoutSeconds),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                        onTap: () => _showChatTimeoutPicker(context, security.chatGraceTimeoutSeconds),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Tombol Uji Coba Kunci Sekarang
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: const Text(
                  'Uji Coba Layar Kunci Sekarang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  security.lock();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const AppLockScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
