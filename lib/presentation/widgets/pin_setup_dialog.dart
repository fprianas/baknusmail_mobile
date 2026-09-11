import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class PinSetupDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const PinSetupDialog({
    super.key,
    this.title = 'Atur PIN 6 Digit',
    this.subtitle,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'Atur PIN 6 Digit',
    String? subtitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PinSetupDialog(
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> with SingleTickerProviderStateMixin {
  int _step = 1; // 1: Buat PIN, 2: Konfirmasi PIN
  String _firstPin = '';
  String _confirmPin = '';
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (_step == 1) {
        if (_firstPin.length < 6) {
          _firstPin += digit;
          if (_firstPin.length == 6) {
            // Lanjut ke konfirmasi setelah jeda singkat
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _step = 2;
                });
              }
            });
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            _validatePinMatch();
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (_step == 1) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Jika backspace di step 2 saat kosong, kembali ke step 1
          _step = 1;
          _firstPin = '';
        }
      }
    });
  }

  void _validatePinMatch() {
    if (_confirmPin == _firstPin) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          Navigator.pop(context, _confirmPin);
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'PIN tidak cocok! Silakan coba lagi.';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePin = _step == 1 ? _firstPin : _confirmPin;

    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Top Row: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _step == 1 ? widget.title : 'Konfirmasi PIN 6 Digit',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, null),
                  tooltip: 'Batal',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Step Subtitle
            Text(
              _step == 1
                  ? (widget.subtitle ?? 'Buat 6 digit PIN untuk keamanan aplikasi Anda.')
                  : 'Masukkan kembali 6 digit PIN yang sama untuk memastikan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // 6 PIN Indicator Dots with Shake Animation
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
                  final isFilled = index < activePin.length;
                  final hasError = _errorMessage != null;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: (hasError ? AppColors.error : AppColors.primary)
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
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

            // Error Text Placeholder
            SizedBox(
              height: 20,
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      _step == 1 ? 'Langkah 1 dari 2' : 'Langkah 2 dari 2',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Keypad Grid
            _buildKeypad(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Column(
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
            // Left Action: Reset / Kembali
            SizedBox(
              width: 72,
              height: 60,
              child: _step == 2
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.primary,
                      tooltip: 'Ulangi PIN',
                      onPressed: () {
                        setState(() {
                          _step = 1;
                          _firstPin = '';
                          _confirmPin = '';
                          _errorMessage = null;
                        });
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            // Middle: Digit 0
            _buildKeyButton('0', isDark),
            // Right Action: Backspace
            SizedBox(
              width: 72,
              height: 60,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                tooltip: 'Hapus',
                onPressed: _onBackspace,
              ),
            ),
          ],
        ),
      ],
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
        borderRadius: BorderRadius.circular(36),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        child: Container(
          width: 72,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
