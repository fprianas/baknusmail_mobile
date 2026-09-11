// lib/widgets/it_care/technician_chat_sheet.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';
import '../../services/it_care_service.dart';

class TechnicianChatSheet extends StatefulWidget {
  final TicketItem? ticket;
  final ITCareService? service;

  const TechnicianChatSheet({
    super.key,
    this.ticket,
    this.service,
  });

  static Future<void> show(
    BuildContext context, {
    TicketItem? ticket,
    ITCareService? service,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TechnicianChatSheet(
        ticket: ticket,
        service: service,
      ),
    );
  }

  @override
  State<TechnicianChatSheet> createState() => _TechnicianChatSheetState();
}

class _TechnicianChatSheetState extends State<TechnicianChatSheet> {
  late final ITCareService _service;
  bool _isLoading = true;
  List<ITTechnicianStaff> _staffList = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ITCareService();
    _loadTechnicians();
  }

  Future<void> _loadTechnicians() async {
    try {
      final list = await _service.getTechnicians(includeAdmins: true);
      if (mounted) {
        setState(() {
          _staffList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TechnicianChatSheet] Error loading technicians: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openChat(
    BuildContext context, {
    required String email,
    required String name,
    required String role,
  }) {
    Navigator.pop(context); // Tutup bottom sheet
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'peerEmail': email,
        'peerName': name,
        'peerTag': role,
      },
    );
  }

  Color _getDepartmentColor(String dept) {
    switch (dept.toLowerCase()) {
      case 'guru':
        return const Color(0xFF0284C7); // Sky blue
      case 'tu':
        return const Color(0xFF059669); // Emerald green
      case 'admin':
        return const Color(0xFF7C3AED); // Purple
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<ITTechnicianStaff> displayStaff = List.from(_staffList);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
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
                          'Hubungi Petugas IT (BaknusChat)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Daftar resmi staf Guru & TU tim IT sekolah',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              // Info Tiket Terkait (Jika ada)
              if (widget.ticket != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Terkait Tiket #${widget.ticket!.ticketCode} - ${widget.ticket!.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Content: Loading State atau List Staf
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Memuat daftar staf tim IT resmi...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (displayStaff.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada petugas IT yang tersedia saat ini.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: displayStaff.length,
                    itemBuilder: (context, index) {
                      final staff = displayStaff[index];
                      final deptColor = _getDepartmentColor(staff.department);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                const Color(0xFFE11D48).withValues(alpha: 0.15),
                            child: Text(
                              staff.avatarInitials,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  staff.fullName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Badge Unit/Department
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: deptColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'Unit ${staff.department}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: deptColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Role Label
                                  Expanded(
                                    child: Text(
                                      staff.roleLabel,
                                      style: TextStyle(
                                        fontSize: 11,
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
                              const SizedBox(height: 3),
                              // Statistik Tiket
                              Row(
                                children: [
                                  Icon(Icons.assignment_turned_in_outlined,
                                      size: 11,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${staff.activeTicketsHandled} aktif • ${staff.totalResolvedTickets} tuntas',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Japri',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => _openChat(
                            context,
                            email: staff.email,
                            name: staff.fullName,
                            role: staff.roleLabel,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
