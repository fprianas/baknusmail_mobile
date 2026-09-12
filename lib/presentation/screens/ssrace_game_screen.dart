import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'create_post_screen.dart';

class SSRaceGameScreen extends StatefulWidget {
  final String? initialUrl;

  const SSRaceGameScreen({
    super.key,
    this.initialUrl,
  });

  @override
  State<SSRaceGameScreen> createState() => _SSRaceGameScreenState();
}

class _SSRaceGameScreenState extends State<SSRaceGameScreen> {
  late final WebViewController _webViewController;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  static const String _defaultGameUrl = 'https://ssrace.baknusgame.smkbn666.sch.id';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final targetUrl = widget.initialUrl ?? _defaultGameUrl;

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[SSRace WebView Error] code: ${error.errorCode}, desc: ${error.description}');
            // Jika HTTPS gagal karena sertifikat di jaringan lokal, coba fallback ke HTTP
            if (error.isForMainFrame == true && targetUrl.startsWith('https://')) {
              final httpFallback = targetUrl.replaceFirst('https://', 'http://');
              debugPrint('[SSRace WebView] Mencoba fallback ke HTTP: $httpFallback');
              _webViewController.loadRequest(Uri.parse(httpFallback));
            } else if (mounted) {
              setState(() {
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      // ============================================================
      // ⚠️ REGISTRASI JAVASCRIPT CHANNEL: BaknusIDBridge
      // ============================================================
      ..addJavaScriptChannel(
        'BaknusIDBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            debugPrint('[BaknusIDBridge] Pesan diterima: ${message.message}');
            final dynamic decoded = jsonDecode(message.message);
            final Map<String, dynamic> data = decoded is Map<String, dynamic>
                ? decoded
                : Map<String, dynamic>.from(decoded as Map);

            if (data['action'] == 'UPDATE_STATUS') {
              final String statusText = data['text']?.toString() ?? '';
              final int score = (data['score'] is num) ? (data['score'] as num).toInt() : 0;
              final bool isVictory = data['isVictory'] == true;
              final String game = data['game']?.toString() ?? 'ssrace';

              debugPrint('[BaknusIDBridge] Menerima update status: $statusText (Skor: $score, Menang: $isVictory)');

              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostPage(
                    initialText: statusText,
                    score: score,
                    isVictory: isVictory,
                    game: game,
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('[BaknusIDBridge] Error parsing JSON: $e');
          }
        },
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  Future<bool> _onWillPop() async {
    final canGoBack = await _webViewController.canGoBack();
    if (canGoBack) {
      await _webViewController.goBack();
      return false;
    }

    if (!mounted) return true;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.sports_esports_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Keluar dari Game?'),
          ],
        ),
        content: const Text(
          'Permainan yang sedang berjalan akan dihentikan jika Anda kembali ke menu utama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Main'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldExit = await _onWillPop();
        if (shouldExit && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1B4B),
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              final nav = Navigator.of(context);
              final shouldExit = await _onWillPop();
              if (shouldExit && mounted) {
                nav.pop();
              }
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sports_motorsports_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SS RACE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'BaknusID Bridge Terhubung',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            // Tombol reload game
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              tooltip: 'Muat Ulang Game',
              onPressed: () => _webViewController.reload(),
            ),
            // Tombol manual Buat Status jika user ingin sharing langsung
            IconButton(
              icon: const Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 22),
              tooltip: 'Update Status Sosial',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostPage(
                      initialText: 'Sedang asik balapan di game SSRace BaknusGame! 🏁🏎️ #SSRace #BaknusID',
                      game: 'ssrace',
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3.0),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    minHeight: 3.0,
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_errorMessage != null)
                Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 54),
                        const SizedBox(height: 16),
                        const Text(
                          'Gagal Memuat Game SSRace',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });
                            _webViewController.reload();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
