// lib/screens/it_care/create_ticket_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';
import '../../services/it_care_service.dart';
import '../../widgets/it_care/technician_chat_sheet.dart';
import '../../presentation/widgets/app_background.dart';

class CreateTicketScreen extends StatefulWidget {
  final ITCareUser currentUser;
  final ITCareService service;

  const CreateTicketScreen({
    super.key,
    required this.currentUser,
    required this.service,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  MetaOptions _options = MetaOptions.defaultOptions();
  bool _isLoadingMeta = true;
  bool _isSubmitting = false;

  // Form fields
  String _selectedService = 'Internet'; // 'Internet' or 'BaknusID'
  String _selectedSubIssue = '';
  String _selectedLocation = '';
  final TextEditingController _customLocationController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedPriority = 'Sedang';

  // For BaknusID
  String _selectedApp = '';
  final TextEditingController _accountNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedService = _tabController.index == 0 ? 'Internet' : 'BaknusID';
        });
      }
    });

    _loadMetaOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customLocationController.dispose();
    _descriptionController.dispose();
    _accountNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadMetaOptions() async {
    try {
      final opts = await widget.service.getMetaOptions();
      if (mounted) {
        setState(() {
          _options = opts;
          if (_options.internetSubIssues.isNotEmpty) {
            _selectedSubIssue = _options.internetSubIssues.first;
          }
          if (_options.locations.isNotEmpty) {
            _selectedLocation = _options.locations.first;
          }
          if (_options.baknusIdApps.isNotEmpty) {
            _selectedApp = _options.baknusIdApps.first;
          }
          _isLoadingMeta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _options = MetaOptions.defaultOptions();
          _selectedSubIssue = _options.internetSubIssues.first;
          _selectedLocation = _options.locations.first;
          _selectedApp = _options.baknusIdApps.first;
          _isLoadingMeta = false;
        });
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final isInternet = _selectedService == 'Internet';

    // Location calculation
    String finalLocation = _selectedLocation;
    if (isInternet) {
      if (_selectedLocation.contains('19. Lainnya') ||
          _selectedLocation.toLowerCase().contains('lainnya')) {
        final customLoc = _customLocationController.text.trim();
        if (customLoc.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Harap tuliskan nama ruangan/lokasi khusus Anda.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        finalLocation = customLoc;
      }
    } else {
      finalLocation = 'Online / Layanan Cloud BaknusID';
    }

    // Sub issue calculation
    String finalSubIssue = isInternet
        ? _selectedSubIssue
        : 'Kendala Layanan $_selectedApp';

    // Description calculation
    String finalDescription = _descriptionController.text.trim();
    if (!isInternet) {
      final notes = _accountNotesController.text.trim();
      if (notes.isNotEmpty) {
        finalDescription =
            'Aplikasi: $_selectedApp\nCatatan Akses/Akun: $notes\n\nKeluhan: $finalDescription';
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final email = widget.currentUser.email.trim().isNotEmpty
          ? widget.currentUser.email.trim()
          : (widget.currentUser.id.contains('@')
              ? widget.currentUser.id.trim()
              : 'pelapor@smkbn666.sch.id');
      final reqId = widget.currentUser.id.trim().isNotEmpty
          ? widget.currentUser.id.trim()
          : email;
      final name = widget.currentUser.name.trim().isNotEmpty
          ? widget.currentUser.name.trim()
          : email.split('@').first;

      final createdTicket = await widget.service.createTicket(
        serviceType: _selectedService,
        subIssue: finalSubIssue,
        location: finalLocation,
        description: finalDescription,
        priority: _selectedPriority,
        requesterId: reqId,
        requesterName: name,
        requesterEmail: email,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Tampilkan dialog sukses dengan pemberitahuan broadcast email
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Laporan Terkirim!',
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
                  'Nomor Tiket Anda:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${createdTicket.ticketCode}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mark_email_read_rounded,
                        size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Notifikasi email darurat otomatis dikirim ke Tim IT Sekolah. Teknisi akan segera menindaklanjuti kendala Anda.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // Return to home & refresh
                },
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48), // BaknusChat signature pink
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Chat Teknisi (Japri)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  TechnicianChatSheet.show(context,
                      ticket: createdTicket, service: widget.service);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Buat Laporan Kendala IT',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoadingMeta
            ? const Center(
                child: SpinKitFadingCircle(
                  color: AppColors.primary,
                  size: 40,
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: [
                    // Service Type Tab Selector
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: const [
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Layanan Internet',
                                      style:
                                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_queue_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Layanan BaknusID',
                                      style:
                                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Content based on Service
                    if (_selectedService == 'Internet')
                      _buildInternetForm(isDark)
                    else
                      _buildBaknusIdForm(isDark),

                    const SizedBox(height: 16),

                    // Priority Selection
                    _buildPrioritySelector(isDark),
                    const SizedBox(height: 16),

                    // Requester Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_outlined,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pelapor: ${widget.currentUser.name}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.currentUser.email,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1E40AF).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submitTicket,
                        child: _isSubmitting
                            ? const SpinKitFadingCircle(
                                color: Colors.white,
                                size: 24,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kirim Laporan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  // ==================== FORMULIR LAYANAN INTERNET ====================
  Widget _buildInternetForm(bool isDark) {
    final isCustomLocation = _selectedLocation.contains('19. Lainnya') ||
        _selectedLocation.toLowerCase().contains('lainnya');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sub Kendala Internet
        const Text(
          'Jenis Kendala Jaringan (Sub Kendala):',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedSubIssue.isNotEmpty
              ? _selectedSubIssue
              : _options.internetSubIssues.first,
          isExpanded: true,
          decoration: _inputDecoration(isDark, hint: 'Pilih jenis kendala'),
          items: _options.internetSubIssues.map((issue) {
            return DropdownMenuItem(
              value: issue,
              child: Text(issue, style: const TextStyle(fontSize: 13.5)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSubIssue = val);
          },
        ),
        const SizedBox(height: 16),

        // 2. Dropdown Lokasi Ruangan (Wajib, 19 Ruangan)
        const Row(
          children: [
            Text(
              'Lokasi Ruangan:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedLocation.isNotEmpty
              ? _selectedLocation
              : _options.locations.first,
          isExpanded: true,
          decoration: _inputDecoration(isDark, hint: 'Pilih lokasi ruangan'),
          items: _options.locations.map((loc) {
            return DropdownMenuItem(
              value: loc,
              child: Text(loc,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedLocation = val);
            }
          },
        ),

        // Jika memilih "19. Lainnya", munculkan TextFormField custom
        if (isCustomLocation) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customLocationController,
            decoration: _inputDecoration(
              isDark,
              hint: 'Tuliskan nama ruangan / lokasi spesifik Anda...',
              prefixIcon: const Icon(Icons.edit_location_alt_rounded, size: 18),
            ),
            validator: (val) {
              if (isCustomLocation && (val == null || val.trim().isEmpty)) {
                return 'Nama ruangan wajib diisi.';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),

        // 3. Deskripsi Keluhan
        const Text(
          'Deskripsi Keluhan:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: _inputDecoration(
            isDark,
            hint:
                'Jelaskan keluhan secara rinci (misal: lampu indikator router merah, wifi terputus-putus sejak jam 09.00)...',
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Deskripsi keluhan wajib diisi.';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ==================== FORMULIR LAYANAN BAKNUSID ====================
  Widget _buildBaknusIdForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Pilihan Aplikasi BaknusID
        const Text(
          'Pilihan Aplikasi / Sistem Digital:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.baknusIdApps.map((app) {
            final isSelected = _selectedApp == app;
            return ChoiceChip(
              label: Text(app),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedApp = app);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 2. Catatan Akun / Akses
        const Text(
          'Catatan Kendala Akses / Akun:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _accountNotesController,
          decoration: _inputDecoration(
            isDark,
            hint: 'Contoh: Lupa sandi, akun terkunci, tidak bisa unggah file',
            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Deskripsi Keluhan
        const Text(
          'Deskripsi Rinci Kendala:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: _inputDecoration(
            isDark,
            hint:
                'Jelaskan apa yang terjadi, pesan error yang muncul, atau langkah yang sudah dicoba...',
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Deskripsi kendala wajib diisi.';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ==================== PRIORITAS KENDALA ====================
  Widget _buildPrioritySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tingkat Prioritas Penanganan:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.priorities.map((pri) {
            final isSelected = _selectedPriority == pri;
            Color chipColor = const Color(0xFF2563EB);
            if (pri.toLowerCase() == 'darurat') {
              chipColor = const Color(0xFFDC2626);
            } else if (pri.toLowerCase() == 'tinggi') {
              chipColor = const Color(0xFFEA580C);
            }

            return ChoiceChip(
              label: Text(pri),
              selected: isSelected,
              selectedColor: chipColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPriority = pri);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark,
      {required String hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : Colors.white,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
