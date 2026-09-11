// lib/screens/it_care/baknus_it_care_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';
import '../../services/it_care_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/it_care/ticket_card.dart';
import '../../widgets/it_care/kpi_card.dart';
import '../../presentation/widgets/app_background.dart';
import '../../widgets/it_care/technician_chat_sheet.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class BaknusITCareHomeScreen extends StatefulWidget {
  const BaknusITCareHomeScreen({super.key});

  @override
  State<BaknusITCareHomeScreen> createState() => _BaknusITCareHomeScreenState();
}

class _BaknusITCareHomeScreenState extends State<BaknusITCareHomeScreen>
    with SingleTickerProviderStateMixin {
  final ITCareService _service = ITCareService();
  final TextEditingController _trackController = TextEditingController();

  TabController? _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  ITCareUser? _user;

  // Tickets data
  List<TicketItem> _allTickets = [];
  KpiDashboard? _kpiDashboard;
  TicketItem? _trackedTicket;
  bool _isTracking = false;
  String? _trackError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuthAndLoadData();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _trackController.dispose();
    super.dispose();
  }

  Future<void> _initAuthAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser;
      final email = currentUser?.email ?? '';
      final password = currentUser?.password ?? '';

      // Auto login ke Backend BaknusITCare dengan kredensial Mailcow yang aktif
      final itUser = await _service.login(
        email: email.isNotEmpty ? email : 'pelapor@smkbn666.sch.id',
        password: password.isNotEmpty ? password : 'demo',
        fallbackDisplayName: currentUser?.displayName,
      );

      _user = itUser;
      _service.setCurrentUser(itUser);

      _setupTabs();
      await _fetchTickets();
    } catch (e) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        final currentUser = auth.currentUser;
        final email = currentUser?.email ?? 'pelapor@smkbn666.sch.id';
        final fallbackUser = ITCareUser(
          id: email,
          name: currentUser?.displayName ?? email.split('@').first,
          email: email,
          role: 'Pelapor',
        );
        _user = fallbackUser;
        _service.setCurrentUser(fallbackUser);
        _setupTabs();
        _fetchTickets();
      }
    }
  }

  void _setupTabs() {
    final tabCount = _user?.isTechnician == true ? 4 : 3;
    _tabController?.dispose();
    _tabController = TabController(length: tabCount, vsync: this);
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    try {
      if (_user?.isTechnician == true) {
        // Teknisi / Admin: Ambil KPI dan semua tiket
        final results = await Future.wait([
          _service.getDashboardKpi(),
          _service.getTickets(role: 'Teknisi'),
        ]);
        if (mounted) {
          setState(() {
            _kpiDashboard = results[0] as KpiDashboard;
            _allTickets = results[1] as List<TicketItem>;
            _isLoading = false;
          });
        }
      } else {
        // Pelapor: Ambil tiket saya
        final tickets = await _service.getTickets(
          userId: _user?.id,
        );
        if (mounted) {
          setState(() {
            _allTickets = tickets;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[BaknusITCare] _fetchTickets error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Jangan timpa jika sudah ada tiket sebelumnya
          if (_allTickets.isEmpty) {
            _errorMessage = 'Gagal memuat data tiket. Tarik ke bawah untuk memuat ulang.';
          }
        });
      }
    }
  }

  Future<void> _handleTrackTicket() async {
    final code = _trackController.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isTracking = true;
      _trackError = null;
      _trackedTicket = null;
    });

    try {
      final ticket = await _service.trackTicket(code);
      if (mounted) {
        setState(() {
          _isTracking = false;
          if (ticket != null) {
            _trackedTicket = ticket;
          } else {
            _trackError = 'Nomor tiket "$code" tidak ditemukan.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTracking = false;
          _trackError = 'Gagal melacak tiket. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  void _openDetail(TicketItem ticket) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          ticketId: ticket.id,
          initialTicket: ticket,
          currentUser: _user ??
              ITCareUser(
                id: '1',
                name: 'Pengguna',
                email: 'user@smkbn666.sch.id',
                role: 'Pelapor',
              ),
          service: _service,
        ),
      ),
    );

    if (updated == true && mounted) {
      _fetchTickets();
    }
  }

  void _openCreateTicket() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(
          currentUser: _user ??
              ITCareUser(
                id: '1',
                name: 'Pengguna',
                email: 'user@smkbn666.sch.id',
                role: 'Pelapor',
              ),
          service: _service,
        ),
      ),
    );

    if (created == true && mounted) {
      _fetchTickets();
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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BaknusITCare',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Bantuan & Pengaduan IT',
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
          actions: [
            // Role Badge in Header
            if (_user != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _user!.isTechnician
                          ? const Color(0xFF1E40AF).withValues(alpha: 0.15)
                          : const Color(0xFF059669).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _user!.isTechnician
                            ? const Color(0xFF1E40AF).withValues(alpha: 0.3)
                            : const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _user!.role,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _user!.isTechnician
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Daftar Tim IT Resmi',
              onPressed: () => TechnicianChatSheet.show(context, service: _service),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan data',
              onPressed: _fetchTickets,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: SpinKitFadingCircle(
                  color: AppColors.primary,
                  size: 44,
                ),
              )
            : _errorMessage != null && _allTickets.isEmpty
                ? _buildErrorView(isDark)
                : RefreshIndicator(
                    onRefresh: _fetchTickets,
                    child: _user?.isTechnician == true
                        ? _buildTechnicianView(isDark)
                        : _buildRequesterView(isDark),
                  ),
      ),
    );
  }

  // ==================== TAMPILAN PELAPOR (GURU / TU / SISWA) ====================
  Widget _buildRequesterView(bool isDark) {
    // Filter tickets:
    // Tab 0: Sedang Diproses (Baru, Diproses, MenungguSparepart)
    // Tab 1: Riwayat Selesai (Selesai, Ditutup)
    final inProgressTickets = _allTickets
        .where((t) => !t.isResolved)
        .toList();
    final resolvedTickets = _allTickets
        .where((t) => t.isResolved)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. TOMBOL UTAMA: + Buat Laporan Kendala IT
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openCreateTicket,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '+ Buat Laporan Kendala IT',
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
        ),
        const SizedBox(height: 10),

        // 1B. TOMBOL BAKNUSCHAT: Konsultasi Japri Teknisi
        Container(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE11D48).withValues(alpha: 0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => TechnicianChatSheet.show(context, service: _service),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFFE11D48), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Konsultasi Japri Teknisi (BaknusChat)',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. FITUR CEPAT: Pelacakan Nomor Tiket
        _buildTrackBox(isDark),
        const SizedBox(height: 20),

        // 3. TAB DAFTAR TIKET SAYA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Tiket Saya',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_allTickets.length} Tiket',
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

        // Tab Bar (3 Tabs: Semua, Diproses, Selesai)
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
            tabs: [
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list_alt_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Semua (${_allTickets.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                      const Icon(Icons.sync_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Diproses (${inProgressTickets.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                      const Icon(Icons.check_circle_outline_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Selesai (${resolvedTickets.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tab Content
        SizedBox(
          height: 480,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTicketList(_allTickets,
                  'Belum ada riwayat laporan tiket yang dibuat.', isDark),
              _buildTicketList(inProgressTickets,
                  'Tidak ada laporan kendala yang sedang diproses.', isDark),
              _buildTicketList(resolvedTickets,
                  'Belum ada riwayat tiket yang telah selesai.', isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAMPILAN TEKNISI / ADMIN (PETUGAS IT) ====================
  Widget _buildTechnicianView(bool isDark) {
    final ticketsBaru =
        _allTickets.where((t) => t.isNew).toList();
    final ticketsDiproses =
        _allTickets.where((t) => t.isInProgress).toList();
    final ticketsSelesai =
        _allTickets.where((t) => t.isResolved).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. KPI DASHBOARD CARD
        if (_kpiDashboard != null) ...[
          KpiDashboardWidget(kpi: _kpiDashboard!),
          const SizedBox(height: 16),
        ],

        // 2. KOTAK PELACAKAN CEPAT
        _buildTrackBox(isDark),
        const SizedBox(height: 16),

        // 3. TAB DAFTAR SEMUA LAPORAN MASUK
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Laporan Masuk Sekolah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Buat Tiket',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
              onPressed: _openCreateTicket,
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark
                ? AppColors.darkTextMuted
                : AppColors.lightTextMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Semua (${_allTickets.length})'),
              Tab(text: 'Baru (${ticketsBaru.length})'),
              Tab(text: 'Diproses (${ticketsDiproses.length})'),
              Tab(text: 'Selesai (${ticketsSelesai.length})'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          height: 480,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTicketList(_allTickets, 'Belum ada tiket masuk.', isDark),
              _buildTicketList(
                  ticketsBaru, 'Tidak ada tiket baru saat ini.', isDark),
              _buildTicketList(ticketsDiproses,
                  'Tidak ada tiket yang sedang diproses.', isDark),
              _buildTicketList(
                  ticketsSelesai, 'Belum ada tiket yang diselesaikan.', isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== KOTAK PELACAKAN CEPAT ====================
  Widget _buildTrackBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Lacak Nomor Tiket Kendala',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trackController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Contoh: NET-101 / BID-101',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleTrackTicket(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                ),
                onPressed: _isTracking ? null : _handleTrackTicket,
                child: _isTracking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Lacak',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_trackError != null) ...[
            const SizedBox(height: 8),
            Text(
              _trackError!,
              style: const TextStyle(fontSize: 11.5, color: Colors.red),
            ),
          ],
          if (_trackedTicket != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Hasil Pelacakan:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TicketCard(
              ticket: _trackedTicket!,
              onTap: () => _openDetail(_trackedTicket!),
              onChatTap: () => TechnicianChatSheet.show(context, ticket: _trackedTicket!),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== LIST TIKET ====================
  Widget _buildTicketList(
      List<TicketItem> tickets, String emptyMessage, bool isDark) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 48,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return TicketCard(
          ticket: ticket,
          onTap: () => _openDetail(ticket),
          onChatTap: () => TechnicianChatSheet.show(context, ticket: ticket, service: _service),
        );
      },
    );
  }

  // ==================== ERROR VIEW ====================
  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.orange),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Gagal menghubungi server.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white)),
              onPressed: _initAuthAndLoadData,
            ),
          ],
        ),
      ),
    );
  }
}
