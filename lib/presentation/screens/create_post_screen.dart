import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/models/jamendo_music.dart';
import '../../data/services/story_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';
import '../widgets/jamendo_music_picker_dialog.dart';
import '../widgets/user_avatar.dart';

class CreatePostPage extends StatefulWidget {
  final String? initialText;
  final int? score;
  final bool? isVictory;
  final String? game;

  const CreatePostPage({
    super.key,
    this.initialText,
    this.score,
    this.isVictory,
    this.game,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final TextEditingController _textController;
  final StoryService _storyService = StoryService();

  String _selectedColor = '#7C3AED';
  List<String> _selectedAudience = ['Semua'];
  JamendoMusic? _selectedMusic;
  bool _isPublishing = false;

  final List<Map<String, dynamic>> _colorOptions = const [
    {'name': 'Ungu Violet', 'hex': '#7C3AED', 'color': Color(0xFF7C3AED)},
    {'name': 'Merah Crimson', 'hex': '#E11D48', 'color': Color(0xFFE11D48)},
    {'name': 'Biru Indigo', 'hex': '#2563EB', 'color': Color(0xFF2563EB)},
    {'name': 'Hijau Emerald', 'hex': '#059669', 'color': Color(0xFF059669)},
    {'name': 'Amber Gold', 'hex': '#D97706', 'color': Color(0xFFD97706)},
    {'name': 'Rose Pink', 'hex': '#DB2777', 'color': Color(0xFFDB2777)},
    {'name': 'Teal Ocean', 'hex': '#0D9488', 'color': Color(0xFF0D9488)},
    {'name': 'Dark Charcoal', 'hex': '#1E293B', 'color': Color(0xFF1E293B)},
  ];

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$clean'));
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    // Jika game menang / skor tinggi, beri default warna menarik
    if (widget.isVictory == true) {
      _selectedColor = '#7C3AED';
    } else if (widget.score != null && widget.score! > 0) {
      _selectedColor = '#2563EB';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleAudience(String tag) {
    setState(() {
      if (tag == 'Semua') {
        _selectedAudience = ['Semua'];
      } else {
        _selectedAudience.remove('Semua');
        if (_selectedAudience.contains(tag)) {
          _selectedAudience.remove(tag);
        } else {
          _selectedAudience.add(tag);
        }
        if (_selectedAudience.isEmpty ||
            (_selectedAudience.contains('Siswa') &&
                _selectedAudience.contains('Guru') &&
                _selectedAudience.contains('TU'))) {
          _selectedAudience = ['Semua'];
        }
      }
    });
  }

  Future<void> _publishStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks status tidak boleh kosong!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final baknus = context.read<BaknusProvider>();
    final user = auth.currentUser;
    final userEmail = user?.email ?? '';
    final rawDisplayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (userEmail.isNotEmpty ? userEmail.split('@').first : 'Pengguna');

    final userTag = UserTagResolver.resolve(
      email: userEmail,
      displayName: rawDisplayName,
      fallbackRole: baknus.userRole,
    );

    if (userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk membuat status.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await _storyService.createStory(
        userEmail: userEmail,
        userName: rawDisplayName,
        userTag: userTag,
        caption: text,
        bgColor: _selectedColor,
        targetAudience: List<String>.from(_selectedAudience),
        type: 'text',
        musicTitle: _selectedMusic?.name,
        artistName: _selectedMusic?.artistName,
        musicAudioUrl: _selectedMusic?.audioUrl,
        musicCoverUrl: _selectedMusic?.coverUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Status sosial berhasil dipublikasikan ke Story Civitas! 🚀'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat status: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = _parseHex(_selectedColor);
    final auth = context.watch<AuthProvider>();
    final baknus = context.watch<BaknusProvider>();
    final user = auth.currentUser;
    final userEmail = user?.email ?? '';
    final rawDisplayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (userEmail.isNotEmpty ? userEmail.split('@').first : 'Pengguna');
    final userTag = UserTagResolver.resolve(
      email: userEmail,
      displayName: rawDisplayName,
      fallbackRole: baknus.userRole,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Status Sosial',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isPublishing ? null : _publishStatus,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_isPublishing ? 'Mengunggah...' : 'Bagikan'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== GAME ORIGIN BANNER (IF APPLICABLE) ====================
            if (widget.game != null || widget.score != null || widget.isVictory != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isVictory == true
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isVictory == true ? const Color(0xFF10B981) : const Color(0xFF6366F1))
                          .withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isVictory == true
                            ? Icons.emoji_events_rounded
                            : Icons.sports_motorsports_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isVictory == true
                                ? 'Kemenangan SSRace! 🚀'
                                : 'Hasil Pertandingan SSRace 🎮',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (widget.score != null)
                            Text(
                              'Skor Pencapaian: ${widget.score}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BaknusID Bridge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ==================== LIVE PREVIEW STORY CARD ====================
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 260),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: activeBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // User Header Info inside Preview
                  Row(
                    children: [
                      UserAvatar(
                        email: userEmail,
                        name: rawDisplayName,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rawDisplayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                userTag,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 24H Story indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, color: Colors.white70, size: 12),
                            SizedBox(width: 4),
                            Text(
                              '24 Jam',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Editable Status Text Box inside card
                  TextField(
                    controller: _textController,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      shadows: [
                        Shadow(blurRadius: 6, color: Colors.black45, offset: Offset(0, 1)),
                      ],
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan atau cerita Anda...',
                      hintStyle: TextStyle(
                        color: Colors.white60,
                        fontSize: 17,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Music Attachment Tag (if any)
                  if (_selectedMusic != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: Color(0xFFF43F5E), size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_selectedMusic!.name} • ${_selectedMusic!.artistName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _selectedMusic = null),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================== COLOR PALETTE PICKER ====================
            Text(
              'Pilih Latar Belakang (Warna):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colorOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final opt = _colorOptions[idx];
                  final hex = opt['hex'] as String;
                  final col = opt['color'] as Color;
                  final isSelected = _selectedColor == hex;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ==================== JAMENDO MUSIC PICKER ====================
            Text(
              'Musik Latar (Jamendo Free Audio):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.library_music_rounded, color: Color(0xFFF43F5E), size: 18),
                  label: Text(
                    _selectedMusic != null
                        ? '🎵 ${_selectedMusic!.name}'
                        : '🎵 Pilih Musik Jamendo',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final music = await JamendoMusicPickerDialog.show(
                      context,
                      initialSelected: _selectedMusic,
                    );
                    if (music != null) {
                      setState(() => _selectedMusic = music);
                    }
                  },
                ),
                if (_selectedMusic != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 22),
                    tooltip: 'Hapus Musik',
                    onPressed: () => setState(() => _selectedMusic = null),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ==================== TARGET AUDIENCE SELECTOR ====================
            Text(
              'Target Audiens Status:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAudienceChip('Semua Civitas', Icons.public_rounded, const Color(0xFF7C3AED), 'Semua', isDark),
                _buildAudienceChip('Siswa', Icons.person_rounded, const Color(0xFF3B82F6), 'Siswa', isDark),
                _buildAudienceChip('Guru', Icons.school_rounded, const Color(0xFF10B981), 'Guru', isDark),
                _buildAudienceChip('TU', Icons.badge_rounded, const Color(0xFF8B5CF6), 'TU', isDark),
              ],
            ),

            const SizedBox(height: 30),

            // ==================== PUBLISH BUTTON ====================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isPublishing ? null : _publishStatus,
                icon: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isPublishing ? 'Mempublikasikan Status...' : '📢 Publikasikan ke Status Civitas',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceChip(String label, IconData icon, Color color, String value, bool isDark) {
    final isSelected = _selectedAudience.contains(value);
    return InkWell(
      onTap: () => _toggleAudience(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
