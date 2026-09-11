// lib/widgets/it_care/rating_dialog.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RatingDialog extends StatefulWidget {
  final int initialRating;
  final String? initialFeedback;
  final Function(int rating, String feedback) onSubmit;

  const RatingDialog({
    super.key,
    this.initialRating = 5,
    this.initialFeedback,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    int initialRating = 5,
    String? initialFeedback,
    required Function(int rating, String feedback) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => RatingDialog(
        initialRating: initialRating,
        initialFeedback: initialFeedback,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _rating;
  late TextEditingController _feedbackController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _feedbackController =
        TextEditingController(text: widget.initialFeedback ?? '');
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Ulasan Kepuasan Layanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Bagaimana penanganan kendala IT oleh tim teknisi sekolah?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starVal = index + 1;
                return IconButton(
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  icon: Icon(
                    starVal <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: starVal <= _rating ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = starVal;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 12),

            // Feedback field
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis komentar atau ucapan terima kasih...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            widget.onSubmit(_rating, _feedbackController.text.trim());
          },
          child: const Text('Kirim Ulasan',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
