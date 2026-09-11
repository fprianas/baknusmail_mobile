// lib/screens/it_care/ticket_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';
import '../../services/it_care_service.dart';
import '../../widgets/it_care/status_badge.dart';
import '../../widgets/it_care/comment_bubble.dart';
import '../../widgets/it_care/rating_dialog.dart';
import '../../widgets/it_care/technician_chat_sheet.dart';
import '../../presentation/widgets/app_background.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final TicketItem? initialTicket;
  final ITCareUser currentUser;
  final ITCareService service;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.initialTicket,
    required this.currentUser,
    required this.service,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  TicketItem? _ticket;
  List<TicketComment> _comments = [];
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _hasChanges = false;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    _fetchDetailAndComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetailAndComments() async {
    try {
      final results = await Future.wait([
        widget.service.getTicketDetail(widget.ticketId),
        widget.service.getComments(widget.ticketId),
      ]);

      if (mounted) {
        setState(() {
          _ticket = results[0] as TicketItem;
          _comments = results[1] as List<TicketComment>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TicketDetailScreen] _fetchDetail error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    setState(() {
      _isSendingComment = true;
    });

    try {
      final newComment = await widget.service.addComment(
        widget.ticketId,
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        userRole: widget.currentUser.role,
        message: text,
      );

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _isSendingComment = false;
          _hasChanges = true;
        });

        // Auto scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleUpdateStatus(String newStatus) async {
    final commentCtrl = TextEditingController();
    final isSelesai = newStatus.toLowerCase() == 'selesai';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              isSelesai
                  ? Icons.check_circle_rounded
                  : Icons.sync_rounded,
              color: isSelesai ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            Text(
              isSelesai ? 'Selesaikan Tiket' : 'Tandai Diproses',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ubah status tiket #${_ticket?.ticketCode} menjadi "$newStatus"?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                hintText: 'Tuliskan catatan teknisi penanganan...',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSelesai ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan Status',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.service.updateStatus(
          widget.ticketId,
          newStatus: newStatus,
          updatedByUserId: widget.currentUser.id,
          updatedByName: widget.currentUser.name,
          comment: commentCtrl.text.trim().isNotEmpty
              ? commentCtrl.text.trim()
              : 'Status diperbarui oleh petugas IT.',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status tiket berhasil diubah ke "$newStatus".'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _hasChanges = true;
          _fetchDetailAndComments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengubah status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRatingSubmit(int rating, String feedback) async {
    try {
      await widget.service.submitRating(
        widget.ticketId,
        rating: rating,
        feedback: feedback,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih! Ulasan kepuasan Anda berhasil disimpan.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _hasChanges = true;
        _fetchDetailAndComments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim ulasan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ticket = _ticket;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Will pop back
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context, _hasChanges),
            ),
            title: Text(
              ticket != null ? '#${ticket.ticketCode}' : 'Detail Tiket',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchDetailAndComments,
              ),
            ],
          ),
          body: _isLoading && ticket == null
              ? const Center(
                  child: SpinKitFadingCircle(
                    color: AppColors.primary,
                    size: 44,
                  ),
                )
              : ticket == null
                  ? const Center(child: Text('Tiket tidak ditemukan.'))
                  : Column(
                      children: [
                        // Scrollable Top Header & Details
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchDetailAndComments,
                            child: ListView(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              children: [
                                // Main Ticket Info Card
                                _buildMainInfoCard(ticket, isDark),
                                const SizedBox(height: 14),

                                // Rekam Jejak Selesai & Solusi
                                if (ticket.isResolved) ...[
                                  _buildResolvedSummaryBanner(ticket, isDark),
                                  const SizedBox(height: 14),
                                ],

                                // Japri via BaknusChat Card
                                _buildBaknusChatDirectCard(ticket, isDark),
                                const SizedBox(height: 14),

                                // Action for Technician
                                if (widget.currentUser.isTechnician) ...[
                                  _buildTechnicianActionBar(ticket, isDark),
                                  const SizedBox(height: 14),
                                ],

                                // Action for Requester (Rating)
                                if (!widget.currentUser.isTechnician &&
                                    ticket.isResolved) ...[
                                  _buildRatingBanner(ticket, isDark),
                                  const SizedBox(height: 14),
                                ],

                                const SizedBox(height: 20),

                                // Discussion / Chat Timeline Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Tanya Jawab & Penanganan',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_comments.length} Pesan',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Chat timeline list
                                if (_comments.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: Text(
                                      'Belum ada pesan tanya jawab pada tiket ini. Kirim pesan di bawah untuk berkonsultasi langsung.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  )
                                else
                                  ..._comments.map((comment) {
                                    final isMe = comment.userId ==
                                            widget.currentUser.id ||
                                        comment.userName.toLowerCase() ==
                                            widget.currentUser.name.toLowerCase();
                                    return CommentBubble(
                                      comment: comment,
                                      isCurrentUser: isMe,
                                    );
                                  }),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // Chat Input Bar at Bottom
                        _buildChatInputBar(isDark),
                      ],
                    ),
        ),
      ),
    );
  }

  // ==================== MAIN TICKET INFO CARD ====================
  Widget _buildMainInfoCard(TicketItem ticket, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ticket.isOverdue
              ? Colors.red.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${ticket.ticketCode}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PriorityBadge(priority: ticket.priority),
                ],
              ),
              StatusBadge(status: ticket.status),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            ticket.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Location
          Row(
            children: [
              const Icon(Icons.room_rounded,
                  size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ticket.location,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Due Date / SLA
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: ticket.isOverdue ? Colors.red : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Batas Waktu (SLA): ${_formatDate(ticket.dueDate)}${ticket.isOverdue ? " (Overdue!)" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        ticket.isOverdue ? FontWeight.bold : FontWeight.normal,
                    color: ticket.isOverdue ? Colors.red : null,
                  ),
                ),
              ),
            ],
          ),

          if (ticket.description != null &&
              ticket.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keluhan / Catatan:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.description!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(height: 10),

          // Metadata Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pelapor',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  Text(
                    ticket.requesterName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Petugas Teknisi',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  Text(
                    ticket.assignedTechnicianName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== AKSI KHUSUS PETUGAS TEKNISI ====================
  Widget _buildTechnicianActionBar(TicketItem ticket, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle_rounded,
                  size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'Aksi Penanganan Teknisi IT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!ticket.isInProgress && !ticket.isResolved)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded,
                        size: 18, color: Colors.white),
                    label: const Text('Tandai Diproses',
                        style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    onPressed: () => _handleUpdateStatus('Diproses'),
                  ),
                ),
              if (!ticket.isInProgress && !ticket.isResolved)
                const SizedBox(width: 10),
              if (!ticket.isResolved)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                    label: const Text('Selesaikan Tiket',
                        style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    onPressed: () => _handleUpdateStatus('Selesai'),
                  ),
                ),
              if (ticket.isResolved)
                const Expanded(
                  child: Text(
                    'Tiket ini telah berstatus Selesai.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET RATING KEPUASAN (PELAPOR) ====================
  Widget _buildRatingBanner(TicketItem ticket, bool isDark) {
    final hasRated = ticket.rating != null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 6),
                  Text(
                    'Ulasan Kepuasan Layanan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (hasRated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '${ticket.rating} / 5',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasRated) ...[
            Text(
              ticket.feedbackComments != null &&
                      ticket.feedbackComments!.isNotEmpty
                  ? '"${ticket.feedbackComments}"'
                  : 'Terima kasih telah memberikan ulasan kepuasan!',
              style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ] else ...[
            const Text(
              'Kendala telah diselesaikan oleh teknisi. Berikan ulasan Anda:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.rate_review_rounded,
                  size: 16, color: Colors.white),
              label: const Text(
                'Beri Rating Bintang 1-5',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                RatingDialog.show(
                  context,
                  initialRating: 5,
                  onSubmit: (rating, feedback) {
                    _handleRatingSubmit(rating, feedback);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==================== REKAM JEJAK SELESAI & SOLUSI ====================
  Widget _buildResolvedSummaryBanner(TicketItem ticket, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF059669).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekam Jejak Selesai & Solusi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                    Text(
                      'Laporan ini telah tuntas ditangani oleh Tim IT Sekolah',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: const Color(0xFF059669).withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Penanganan Selesai',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(ticket.resolvedAt ?? ticket.updatedAt ?? ticket.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Dituntaskan Oleh',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.assignedTechnicianName.isNotEmpty
                        ? ticket.assignedTechnicianName
                        : 'Petugas IT Care',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ticket.feedbackComments != null &&
              ticket.feedbackComments!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan/Ulasan: "${ticket.feedbackComments}"',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== BAKNUSCHAT JAPRI CARD ====================
  Widget _buildBaknusChatDirectCard(TicketItem ticket, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Color(0xFFE11D48),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konsultasi Japri Teknisi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE11D48),
                  ),
                ),
                Text(
                  'Chat langsung lewat fitur BaknusChat sekolah',
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
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => TechnicianChatSheet.show(context,
                ticket: ticket, service: widget.service),
            child: const Text(
              'Japri',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CHAT INPUT BAR ====================
  Widget _buildChatInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan tanya jawab...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                onSubmitted: (_) => _handleSendComment(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: IconButton(
                iconSize: 20,
                color: Colors.white,
                icon: _isSendingComment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                onPressed: _isSendingComment ? null : _handleSendComment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
