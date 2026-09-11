import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/user_avatar.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const AppLockScreen({
    super.key,
    this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isVerifying = false;
  bool _hasAutoPromptedBiometric = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 14)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Otomatis memicu pemindai biometrik hanya sekali saat layar kunci pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricOnStart();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricOnStart() async {
    if (!mounted || _hasAutoPromptedBiometric) return;
    _hasAutoPromptedBiometric = true;

    final security = context.read<SecurityProvider>();
    if (security.isBiometricEnabled && security.canCheckBiometrics) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted && security.isLocked && !security.isAuthenticating) {
        final result = await security.authenticateWithBiometrics(
          reason: 'Verifikasi biometrik untuk membuka BaknusMail',
        );
        if (result.success && mounted) {
          _handleSuccessUnlock();
        }
      }
    }
  }

  void _onKeyPress(String digit) {
    if (_isVerifying) return;
    HapticFeedback.lightImpact();

    setState(() {
      _errorMessage = null;
      if (_enteredPin.length < 6) {
        _enteredPin += digit;
        if (_enteredPin.length == 6) {
          _verifyPin();
        }
      }
    });
  }

  void _onBackspace() {
    if (_isVerifying) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  void _verifyPin() {
    _isVerifying = true;
    final security = context.read<SecurityProvider>();
    final isCorrect = security.verifyPin(_enteredPin);

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      security.unlock();
      _handleSuccessUnlock();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'PIN salah, silakan coba lagi';
        _enteredPin = '';
        _isVerifying = false;
      });
    }
  }

  void _handleSuccessUnlock() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupa PIN & Keluar Akun?'),
        content: const Text(
          'Jika Anda lupa PIN, Anda dapat keluar dari akun ini dan masuk kembali menggunakan email & kata sandi sekolah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar Akun'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final security = context.read<SecurityProvider>();
      final auth = context.read<AuthProvider>();
      await security.clearPin();
      await auth.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final security = context.watch<SecurityProvider>();
    final user = auth.currentUser;

    return PopScope(
      canPop: false, // Cegah tombol back keluar dari lock screen tanpa unlock
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Header: User Profile / Shield Icon
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              if (user != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryLight.withValues(alpha: 0.6),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: UserAvatar(
                                    email: user.email,
                                    name: user.displayName,
                                    radius: 36,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Halo, ${user.displayName}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aplikasi Terkunci Demi Keamanan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'BaknusMail Terkunci',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // PIN Dots Indicator with Shake Animation
                              AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  final offset = _shakeAnimation.value * (_errorMessage != null ? 1 : 0);
                                  return Transform.translate(
                                    offset: Offset(offset, 0),
                                    child: child,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    final isFilled = index < _enteredPin.length;
                                    final hasError = _errorMessage != null;

                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 9),
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: hasError
                                            ? AppColors.error
                                            : (isFilled ? AppColors.primary : Colors.transparent),
                                        border: Border.all(
                                          color: hasError
                                              ? AppColors.error
                                              : (isFilled
                                                  ? AppColors.primary
                                                  : (isDark
                                                      ? AppColors.darkBorder
                                                      : AppColors.lightBorder)),
                                          width: 2,
                                        ),
                                        boxShadow: isFilled
                                            ? [
                                                BoxShadow(
                                                  color: (hasError ? AppColors.error : AppColors.primary)
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Status or Error Message
                              SizedBox(
                                height: 22,
                                child: _errorMessage != null
                                    ? Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : Text(
                                        'Masukkan 6 digit PIN Anda',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                              ),
                            ],
                          ),

                          // Numeric Keypad
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                _buildKeypadRow(['1', '2', '3'], isDark),
                                const SizedBox(height: 14),
                                _buildKeypadRow(['4', '5', '6'], isDark),
                                const SizedBox(height: 14),
                                _buildKeypadRow(['7', '8', '9'], isDark),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Left: Biometric trigger button
                                    SizedBox(
                                      width: 74,
                                      height: 64,
                                      child: (security.isBiometricEnabled && security.canCheckBiometrics)
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.fingerprint_rounded,
                                                size: 36,
                                                color: AppColors.primary,
                                              ),
                                              tooltip: security.biometricLabel,
                                              onPressed: () async {
                                                final result = await security.authenticateWithBiometrics();
                                                if (result.success && mounted) {
                                                  _handleSuccessUnlock();
                                                } else if (mounted && result.errorMessage != null && !result.errorMessage!.contains('dibatalkan')) {
                                                  setState(() {
                                                    _errorMessage = result.errorMessage;
                                                  });
                                                }
                                              },
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    // Center: 0
                                    _buildKeyButton('0', isDark),
                                    // Right: Backspace
                                    SizedBox(
                                      width: 74,
                                      height: 64,
                                      child: IconButton(
                                        icon: const Icon(Icons.backspace_outlined, size: 26),
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                        tooltip: 'Hapus',
                                        onPressed: _onBackspace,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Forgot PIN / Sign Out option
                                TextButton.icon(
                                  onPressed: _handleLogout,
                                  icon: const Icon(Icons.help_outline_rounded, size: 16),
                                  label: const Text(
                                    'Lupa PIN? Keluar dari Akun',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeyButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeyButton(String digit, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(digit),
        borderRadius: BorderRadius.circular(38),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        child: Container(
          width: 74,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
