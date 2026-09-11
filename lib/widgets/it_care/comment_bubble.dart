// lib/widgets/it_care/comment_bubble.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';

class CommentBubble extends StatelessWidget {
  final TicketComment comment;
  final bool isCurrentUser;

  const CommentBubble({
    super.key,
    required this.comment,
    required this.isCurrentUser,
  });

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTech = comment.isTechnician;
    final isSystemStatus = comment.message.startsWith('[Status diubah');

    if (isSystemStatus) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  comment.message,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: isTech
                  ? const Color(0xFF1E40AF)
                  : const Color(0xFF059669),
              child: Text(
                comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isCurrentUser
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name & Role badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCurrentUser ? 'Anda' : comment.userName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? Colors.white.withValues(alpha: 0.9)
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isTech
                              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                              : const Color(0xFF059669).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isTech ? 'IT Helpdesk' : 'Pelapor',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isCurrentUser
                                ? Colors.white
                                : (isTech
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF059669)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Message text
                  Text(
                    comment.message,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isCurrentUser
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    _formatTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isCurrentUser
                          ? Colors.white70
                          : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryDark,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
