// lib/widgets/it_care/ticket_card.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';
import 'status_badge.dart';

class TicketCard extends StatelessWidget {
  final TicketItem ticket;
  final VoidCallback onTap;
  final VoidCallback? onChatTap;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.onChatTap,
  });

  String _formatDisplayDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ticket.isOverdue
              ? Colors.red.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: ticket.isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ticket Code & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${ticket.ticketCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0284C7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PriorityBadge(priority: ticket.priority),
                        if (ticket.isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Overdue SLA',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    StatusBadge(status: ticket.status, isCompact: true),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  ticket.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Location info
                Row(
                  children: [
                    Icon(
                      Icons.room_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ticket.location,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 10),

                // Bottom row: Requester & Comment count + Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            ticket.requesterName.isNotEmpty
                                ? ticket.requesterName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            ticket.requesterName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (onChatTap != null) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: onChatTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.chat_bubble_rounded,
                                      size: 11, color: Color(0xFFE11D48)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Japri',
                                    style: TextStyle(
                                      color: Color(0xFFE11D48),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (ticket.rating != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 15, color: Colors.amber),
                              Text(
                                '${ticket.rating}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ],
                        if (ticket.commentsCount > 0) ...[
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ticket.commentsCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDisplayDate(ticket.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
