// lib/widgets/it_care/status_badge.dart

import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    IconData icon;
    String label = status;

    final lower = status.toLowerCase();
    if (lower == 'baru') {
      bg = const Color(0xFF2563EB).withValues(alpha: 0.12);
      text = const Color(0xFF2563EB);
      icon = Icons.fiber_new_rounded;
    } else if (lower == 'diproses') {
      bg = const Color(0xFFD97706).withValues(alpha: 0.12);
      text = const Color(0xFFD97706);
      icon = Icons.sync_rounded;
    } else if (lower == 'menunggasparepart') {
      bg = const Color(0xFF7C3AED).withValues(alpha: 0.12);
      text = const Color(0xFF7C3AED);
      icon = Icons.hourglass_top_rounded;
      label = 'Menunggu Sparepart';
    } else if (lower == 'selesai') {
      bg = const Color(0xFF059669).withValues(alpha: 0.12);
      text = const Color(0xFF059669);
      icon = Icons.check_circle_rounded;
    } else if (lower == 'ditutup') {
      bg = const Color(0xFF4B5563).withValues(alpha: 0.12);
      text = const Color(0xFF4B5563);
      icon = Icons.lock_outline_rounded;
    } else {
      bg = Colors.grey.withValues(alpha: 0.15);
      text = Colors.grey.shade700;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    final lower = priority.toLowerCase();
    if (lower == 'darurat') {
      color = const Color(0xFFDC2626);
    } else if (lower == 'tinggi') {
      color = const Color(0xFFEA580C);
    } else if (lower == 'sedang') {
      color = const Color(0xFF2563EB);
    } else {
      color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
