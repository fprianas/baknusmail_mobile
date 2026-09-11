import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'core/config/mailcow_config.dart';
import 'core/theme/app_theme.dart';
import 'data/services/fcm_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/mailcow_api_service.dart';
import 'data/services/imap_service.dart';
import 'data/services/smtp_service.dart';
import 'data/services/baknus_api_service.dart';
import 'data/services/weather_service.dart';
import 'data/services/avatar_api_service.dart';
import 'data/services/security_service.dart';
import 'data/services/attendance_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/mailcow_provider.dart';
import 'providers/mail_provider.dart';
import 'providers/baknus_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/security_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/baknus_portal_screen.dart';
import 'presentation/screens/baknus_attend_screen.dart';
import 'presentation/screens/baknus_drive_screen.dart';
import 'presentation/screens/baknus_talim_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/email_detail_screen.dart';
import 'presentation/screens/compose_screen.dart';
import 'presentation/screens/server_status_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/security_settings_screen.dart';
import 'presentation/screens/app_lock_screen.dart';
import 'presentation/screens/baknus_chat_screen.dart';
import 'presentation/screens/weather_traffic_detail_screen.dart';
import 'screens/it_care/baknus_it_care_home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  try {
    final fcmService = FCMService();
    await fcmService.showBackgroundNotification(message);
  } catch (e) {
    debugPrint("Background notification error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint("Locale formatting init warning: $e");
  }

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init warning: $e");
  }

  final fcmService = FCMService();
  try {
    await fcmService.init();
  } catch (e) {
    debugPrint("FCM init warning: $e");
  }

  // Initialize storage
  final storageService = await StorageService.init();
  final apiService = MailcowApiService();
  final imapService = ImapService();
  final smtpService = SmtpService();

  final baknusApiService = BaknusApiService();
  final attendanceService = AttendanceService();
  final weatherService = WeatherService();
  final avatarApiService = AvatarApiService();
  final securityService = SecurityService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<MailcowApiService>.value(value: apiService),
        Provider<AttendanceService>.value(value: attendanceService),
        Provider<BaknusApiService>.value(value: baknusApiService),
        Provider<WeatherService>.value(value: weatherService),
        Provider<AvatarApiService>.value(value: avatarApiService),
        Provider<ImapService>.value(value: imapService),
        Provider<SmtpService>.value(value: smtpService),
        Provider<FCMService>.value(value: fcmService),
        Provider<SecurityService>.value(value: securityService),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(storageService, imapService, apiService, fcmService),
        ),
        ChangeNotifierProvider(
          create: (_) => SecurityProvider(storageService, securityService),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(attendanceService),
        ),
        ChangeNotifierProvider(
          create: (_) => BaknusProvider(baknusApiService),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherProvider(weatherService),
        ),
        ChangeNotifierProvider(
          create: (_) => MailcowProvider(apiService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MailProvider>(
          create: (ctx) => MailProvider(
            storageService,
            imapService,
            smtpService,
            ctx.read<AuthProvider>(),
          ),
          update: (ctx, auth, previous) {
            if (previous != null) {
              if (!auth.isAuthenticated) {
                previous.clearMailbox();
              }
              return previous;
            }
            return MailProvider(storageService, imapService, smtpService, auth);
          },
        ),
      ],
      child: const BaknusMailApp(),
    ),
  );
}

class BaknusMailApp extends StatefulWidget {
  const BaknusMailApp({super.key});

  @override
  State<BaknusMailApp> createState() => _BaknusMailAppState();
}

class _BaknusMailAppState extends State<BaknusMailApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final security = context.read<SecurityProvider>();
    if (state == AppLifecycleState.paused) {
      security.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      security.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: MailcowConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/portal': (context) => const BaknusPortalScreen(),
        '/home': (context) => const HomeScreen(),
        '/attend': (context) => const BaknusAttendScreen(),
        '/drive': (context) => const BaknusDriveScreen(),
        '/talim': (context) => const BaknusTalimScreen(),
        '/email_detail': (context) => const EmailDetailScreen(),
        '/compose': (context) => const ComposeScreen(),
        '/server_status': (context) => const ServerStatusScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/security_settings': (context) => const SecuritySettingsScreen(),
        '/app_lock': (context) => const AppLockScreen(),
        '/chat': (context) => const BaknusChatScreen(),
        '/weather_traffic_detail': (context) => const WeatherTrafficDetailScreen(),
        '/it_care': (context) => const BaknusITCareHomeScreen(),
      },
      builder: (context, child) {
        return Consumer<SecurityProvider>(
          builder: (context, security, _) {
            final auth = context.watch<AuthProvider>();
            final isLocked = security.isLocked && auth.isAuthenticated;

            return Stack(
              children: [
                if (child != null) child,
                if (isLocked)
                  const Positioned.fill(
                    child: AppLockScreen(key: ValueKey('app_lock_screen_overlay')),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

