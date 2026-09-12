import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../providers/mail_provider.dart';
import 'storage_service.dart';

class PendingNotificationTarget {
  final String route;
  final Map<String, dynamic>? arguments;

  PendingNotificationTarget({required this.route, this.arguments});
}

// ==============================================================================
// ⛔ PERINGATAN KERAS / STRICT PROTECTED CODE (AGENTS & DEVELOPERS):
// BERKAS INI MENGATUR SISTEM PUSH NOTIFICATION FCM & TELAH TERINTEGRASI DENGAN
// SERVER PRODUKSI BACKEND (COMMIT 0f471ee).
// DILARANG MENGUBAH / MENGGANTI:
// 1. Channel ID 'channel_email_umum_v4'
// 2. Sound name 'sound_umum'
// 3. Logika multi-token Firestore ('fcm_tokens') & session recovery di onTokenRefresh
// PERUBAHAN APAPUN AKAN MERUSAK NOTIFIKASI DI HP PENGGUNA!
// ==============================================================================
class FCMService {
  FirebaseMessaging? get _firebaseMessaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static PendingNotificationTarget? pendingTarget;
  String? _currentRegisteredEmail;

  /// Memeriksa apakah aplikasi dibuka dari klik notifikasi (Terminated / Cold Start)
  Future<PendingNotificationTarget?> checkPendingNotificationLaunch() async {
    if (pendingTarget != null) {
      final target = pendingTarget;
      pendingTarget = null;
      return target;
    }

    try {
      final initialMsg = await _firebaseMessaging?.getInitialMessage();
      if (initialMsg != null) {
        return _extractTargetFromRemoteMessage(initialMsg);
      }
    } catch (_) {}

    try {
      final launchDetails =
          await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse?.payload != null) {
        return _extractTargetFromPayload(
            launchDetails!.notificationResponse!.payload!);
      }
    } catch (_) {}

    return null;
  }

  PendingNotificationTarget _extractTargetFromRemoteMessage(RemoteMessage message) {
    String route = message.data['route']?.toString() ?? '';
    if (route == '/chat') {
      final peerEmail = message.data['peer_email'] ?? message.data['sender_email'];
      final peerName = message.data['peer_name'] ?? message.data['sender_name'];
      final peerTag = message.data['peer_tag'] ?? message.data['sender_tag'];
      return PendingNotificationTarget(
        route: '/chat',
        arguments: {
          'peerEmail': peerEmail,
          'peerName': peerName,
          'peerTag': peerTag,
        },
      );
    }

    if (route.isEmpty || route == '/home') {
      final senderStr =
          message.data['email_from'] ?? message.data['from'] ?? message.data['sender_name'] ?? '';
      final subjectStr =
          message.data['subject'] ?? message.data['title'] ?? message.data['notif_title'] ?? '';
      final titleStr = message.data['notif_title'] ?? message.notification?.title ?? '';
      final bodyStr = message.data['notif_body'] ?? message.data['body'] ?? message.data['message'] ?? message.notification?.body ?? '';
      final config = _getChannelAndSound(senderStr, subjectStr, titleStr, bodyStr);
      if (config['id'] == 'channel_baknus_attend_v4') {
        route = '/attend';
      } else if (config['id'] == 'channel_baknus_drive_v4') {
        route = '/drive';
      } else if (config['id'] == 'channel_baknus_talim_v4') {
        route = '/talim';
      } else {
        route = '/home';
      }
    }

    return PendingNotificationTarget(route: route);
  }

  PendingNotificationTarget? _extractTargetFromPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      String route = decoded['route']?.toString() ?? '';
      if (route == '/chat') {
        return PendingNotificationTarget(
          route: '/chat',
          arguments: {
            'peerEmail': decoded['peer_email'] ?? decoded['sender_email'],
            'peerName': decoded['peer_name'] ?? decoded['sender_name'],
            'peerTag': decoded['peer_tag'] ?? decoded['sender_tag'],
          },
        );
      }

      if (route.isEmpty || route == '/home') {
        final senderStr =
            decoded['email_from'] ?? decoded['from'] ?? decoded['sender_name'] ?? '';
        final subjectStr =
            decoded['subject'] ?? decoded['title'] ?? decoded['notif_title'] ?? '';
        final titleStr = decoded['notif_title'] ?? decoded['title'] ?? '';
        final bodyStr = decoded['notif_body'] ?? decoded['body'] ?? decoded['message'] ?? '';
        final config = _getChannelAndSound(senderStr, subjectStr, titleStr, bodyStr);
        if (config['id'] == 'channel_baknus_attend_v4') {
          route = '/attend';
        } else if (config['id'] == 'channel_baknus_drive_v4') {
          route = '/drive';
        } else if (config['id'] == 'channel_baknus_talim_v4') {
          route = '/talim';
        } else {
          route = '/home';
        }
      }

      return PendingNotificationTarget(route: route);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    final messaging = _firebaseMessaging;
    // 1. Minta izin notifikasi jika FCM tersedia
    if (messaging != null) {
      try {
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted permission');
        } else {
          debugPrint('User declined or has not accepted permission');
        }

        messaging.onTokenRefresh.listen((newToken) async {
          String? email = _currentRegisteredEmail;
          if (email == null || email.isEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final rawUser = prefs.getString(StorageService.keyUser);
              if (rawUser != null) {
                final userMap = jsonDecode(rawUser) as Map<String, dynamic>;
                email = userMap['email']?.toString();
              }
            } catch (_) {}
          }
          if (email != null && email.isNotEmpty) {
            debugPrint('FCM token refreshed, re-registering for $email');
            registerToken(email);
          }
        });
      } catch (e) {
        debugPrint('Warning: FCM permission request failed: $e');
      }
    }

    // 2. Setup Local Notifications untuk menangani notifikasi saat aplikasi dibuka (foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(null, response.payload);
      },
    );

    // Buat Notification Channel khusus dengan suara custom di Android & minta izin notifikasi Android 13+
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Warning: Android local notification permission request failed: $e');
      }

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_attend_v4',
          'BaknusAttend Notifications',
          description: 'Notifikasi presensi dan kehadiran BaknusAttend',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_attend'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_drive_v4',
          'BaknusDrive Notifications',
          description: 'Notifikasi penyimpanan dan berkas BaknusDrive',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_drive'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_talim_v4',
          'BaknusTalim Notifications',
          description: 'Notifikasi kegiatan BaknusTalim',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_talim'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_email_umum_v4',
          'Email Notifications',
          description: 'Notifikasi email umum & pesan',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
          playSound: true,
        ),
      );
    }

    // 3. Dengarkan notifikasi jika messaging tersedia
    if (messaging != null) {
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          final route = message.data['route']?.toString() ?? '';
          if (route != '/chat') {
            final mailProvider = navigatorKey.currentContext?.read<MailProvider>();
            if (mailProvider != null) {
              mailProvider.loadFoldersAndEmails().catchError((_) {});
            }
          }

          _showLocalNotification(message);
        });

        // 4. Ketika notifikasi di-tap dari latar belakang (background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
          debugPrint('Notification clicked from background: ${message.data}');
          _handleNotificationTap(message, null);
        });

        // 5. Ketika aplikasi dibuka dari kondisi mati (terminated) karena notifikasi di-tap
        messaging.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            debugPrint('App launched from terminated notification: ${message.data}');
            _handleNotificationTap(message, null);
          }
        });
      } catch (_) {}
    }
  }

  // Menampilkan notifikasi background
  Future<void> showBackgroundNotification(RemoteMessage message) async {
    // Jika pesan sudah mengandung payload notification langsung dari FCM SDK,
    // Android FCM SDK sudah menampilkan notifikasi secara otomatis di status bar.
    // Menampilkan local notification di sini akan menyebabkan notifikasi ganda (double).
    if (message.notification != null) {
      debugPrint('Skipping local notification in background because FCM SDK handled message.notification');
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_attend_v4',
          'BaknusAttend Notifications',
          description: 'Notifikasi presensi dan kehadiran BaknusAttend',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_attend'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_drive_v4',
          'BaknusDrive Notifications',
          description: 'Notifikasi penyimpanan dan berkas BaknusDrive',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_drive'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_talim_v4',
          'BaknusTalim Notifications',
          description: 'Notifikasi kegiatan BaknusTalim',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_talim'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_email_umum_v4',
          'Email Notifications',
          description: 'Notifikasi email umum & pesan',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
          playSound: true,
        ),
      );
    }

    await _showLocalNotification(message);
  }

  // Mendapatkan channel dan suara berdasarkan pengirim, subjek, judul, & isi pesan
  Map<String, String> _getChannelAndSound(String sender, String subject, [String? title, String? body]) {
    final combined = '${sender.toLowerCase()} ${subject.toLowerCase()} ${title?.toLowerCase() ?? ''} ${body?.toLowerCase() ?? ''}';

    if (combined.contains('attend') ||
        combined.contains('presensi') ||
        combined.contains('kehadiran') ||
        combined.contains('baknusattend')) {
      return {
        'id': 'channel_baknus_attend_v4',
        'name': 'BaknusAttend Notifications',
        'desc': 'Notifikasi presensi dan kehadiran BaknusAttend',
        'sound': 'sound_baknus_attend',
      };
    } else if (combined.contains('drive') ||
        combined.contains('berkas') ||
        combined.contains('penyimpanan') ||
        combined.contains('baknusdrive')) {
      return {
        'id': 'channel_baknus_drive_v4',
        'name': 'BaknusDrive Notifications',
        'desc': 'Notifikasi penyimpanan dan berkas BaknusDrive',
        'sound': 'sound_baknus_drive',
      };
    } else if (combined.contains('talim') ||
        combined.contains('ta\'lim') ||
        combined.contains('kajian') ||
        combined.contains('baknustalim')) {
      return {
        'id': 'channel_baknus_talim_v4',
        'name': 'BaknusTalim Notifications',
        'desc': 'Notifikasi kegiatan BaknusTalim',
        'sound': 'sound_baknus_talim',
      };
    } else {
      return {
        'id': 'channel_email_umum_v4',
        'name': 'Email Notifications',
        'desc': 'Notifikasi email umum & pesan',
        'sound': 'sound_umum',
      };
    }
  }

  // Menampilkan notifikasi manual saat aplikasi sedang di foreground/background
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final String senderStr =
        message.data['email_from'] ?? message.data['from'] ?? message.data['sender_name'] ?? '';
    final String subjectStr =
        message.data['subject'] ?? message.data['title'] ?? message.data['notif_title'] ?? '';
    final String titleFromPayload = message.data['notif_title'] ?? message.notification?.title ?? '';
    final String bodyFromPayload = message.data['notif_body'] ?? message.data['body'] ?? message.data['message'] ?? message.data['text'] ?? message.notification?.body ?? '';

    // Smart detection channel & sound
    final autoDetectedConfig = _getChannelAndSound(senderStr, subjectStr, titleFromPayload, bodyFromPayload);
    final String channelIdFromData = message.data['channel_id'] ?? '';
    final String soundNameFromData = message.data['sound_name'] ?? '';

    late Map<String, String> channelConfig;
    if (channelIdFromData.isNotEmpty) {
      String sound = soundNameFromData;
      String name = 'Email Notifications';
      String desc = 'Notifikasi email umum & pesan';

      if (channelIdFromData == 'channel_baknus_attend_v4' || channelIdFromData == 'channel_baknus_attend_v3') {
        sound = sound.isEmpty ? 'sound_baknus_attend' : sound;
        name = 'BaknusAttend Notifications';
        desc = 'Notifikasi presensi dan kehadiran BaknusAttend';
      } else if (channelIdFromData == 'channel_baknus_drive_v4' || channelIdFromData == 'channel_baknus_drive_v3') {
        sound = sound.isEmpty ? 'sound_baknus_drive' : sound;
        name = 'BaknusDrive Notifications';
        desc = 'Notifikasi penyimpanan dan berkas BaknusDrive';
      } else if (channelIdFromData == 'channel_baknus_talim_v4' || channelIdFromData == 'channel_baknus_talim_v3') {
        sound = sound.isEmpty ? 'sound_baknus_talim' : sound;
        name = 'BaknusTalim Notifications';
        desc = 'Notifikasi kegiatan BaknusTalim';
      } else {
        sound = sound.isEmpty ? 'sound_umum' : sound;
      }

      final String cleanBase = channelIdFromData
          .replaceAll(RegExp(r'^channel_'), '')
          .replaceAll(RegExp(r'_v\d+$'), '');
      final String resolvedId = 'channel_${cleanBase}_v4';

      channelConfig = {
        'id': resolvedId,
        'name': name,
        'desc': desc,
        'sound': sound,
      };
    } else {
      channelConfig = autoDetectedConfig;
    }

    String title = titleFromPayload;
    if (title.isEmpty || title == 'Pesan Masuk' || title == 'Email Baru') {
      if (channelConfig['id'] == 'channel_baknus_attend_v4') {
        title = 'BaknusAttend - Presensi';
      } else if (channelConfig['id'] == 'channel_baknus_drive_v4') {
        title = 'BaknusDrive - Berkas';
      } else if (channelConfig['id'] == 'channel_baknus_talim_v4') {
        title = 'BaknusTalim - Kegiatan';
      } else {
        title = senderStr.isNotEmpty ? senderStr.split('<').first.trim() : 'Pesan Masuk';
      }
    }

    final String body = bodyFromPayload.isNotEmpty
        ? bodyFromPayload
        : (subjectStr.isNotEmpty ? subjectStr : 'Anda mendapat pesan masuk');

    String targetRoute = message.data['route'] ?? '';
    if (targetRoute.isEmpty || targetRoute == '/home') {
      if (channelConfig['id'] == 'channel_baknus_attend_v4') {
        targetRoute = '/attend';
      } else if (channelConfig['id'] == 'channel_baknus_drive_v4') {
        targetRoute = '/drive';
      } else if (channelConfig['id'] == 'channel_baknus_talim_v4') {
        targetRoute = '/talim';
      } else {
        targetRoute = '/home';
      }
    }

    final isChat = targetRoute == '/chat';
    final payloadMap = Map<String, dynamic>.from(message.data);
    payloadMap['route'] = targetRoute;

    final notifId = isChat
        ? (message.data['peer_email'] ?? message.data['sender_email'] ?? 'chat').hashCode
        : (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

    final notifTag = isChat
        ? 'baknus_chat_${message.data["peer_email"] ?? message.data["sender_email"] ?? "dm"}'
        : 'baknus_notif_${channelConfig["id"]}_$notifId';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelConfig['id']!,
      channelConfig['name']!,
      channelDescription: channelConfig['desc'],
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(channelConfig['sound']!),
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      tag: notifTag,
      groupKey: isChat
          ? 'com.baknus.baknusmail.CHAT'
          : 'com.baknus.baknusmail.NOTIFICATIONS',
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await _localNotificationsPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: jsonEncode(payloadMap),
      );
    } catch (e) {
      debugPrint('Warning: Local notification with custom sound failed: $e. Fallback to default sound.');
      final fallbackAndroidDetails = AndroidNotificationDetails(
        channelConfig['id']!,
        channelConfig['name']!,
        channelDescription: channelConfig['desc'],
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        tag: notifTag,
      );
      await _localNotificationsPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: fallbackAndroidDetails),
        payload: jsonEncode(payloadMap),
      );
    }
  }

  // Navigasi ke layar target (Chat Japri / BaknusAttend / Home / Drive / Talim) saat notifikasi di-klik
  void _handleNotificationTap(RemoteMessage? message, [String? localPayload]) async {
    PendingNotificationTarget? target;
    if (message != null) {
      target = _extractTargetFromRemoteMessage(message);
    } else if (localPayload != null && localPayload.isNotEmpty) {
      target = _extractTargetFromPayload(localPayload);
    }

    if (target == null) return;

    final context = navigatorKey.currentContext;

    if (target.route == '/chat') {
      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: target.arguments,
      );
      return;
    }

    if (target.route == '/attend') {
      navigatorKey.currentState?.pushNamed('/attend');
      return;
    }

    if (target.route == '/drive') {
      navigatorKey.currentState?.pushNamed('/drive');
      return;
    }

    if (target.route == '/talim') {
      navigatorKey.currentState?.pushNamed('/talim');
      return;
    }

    // Default Email Masuk: Buka Inbox (/home)
    if (context != null) {
      try {
        final mailProvider = context.read<MailProvider>();
        mailProvider.selectInboxAndRefresh().catchError((_) {});
      } catch (_) {}
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  // Mendapatkan token dan menyimpannya ke Firestore (dipanggil saat login, mendukung multi-device)
  Future<void> registerToken(String email) async {
    final messaging = _firebaseMessaging;
    final firestore = _firestore;
    if (messaging == null || firestore == null) return;

    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;
    _currentRegisteredEmail = cleanEmail;

    try {
      String? token = await messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Warning: FCM getToken() timed out due to Emulator DNS/network issues.');
          return null;
        },
      );
      if (token != null) {
        debugPrint('FCM Token: $token');
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .set({
              'fcm_token': token,
              'fcm_tokens': FieldValue.arrayUnion([token]),
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        debugPrint('Token registered for $cleanEmail');
      }
    } catch (e) {
      debugPrint('Warning: Could not save token to Firestore (Network/DNS issue): $e');
    }
  }

  // Menghapus token dari Firestore (dipanggil saat logout)
  Future<void> unregisterToken(String email) async {
    final messaging = _firebaseMessaging;
    final firestore = _firestore;
    if (messaging == null || firestore == null) return;

    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;
    _currentRegisteredEmail = null;

    try {
      String? token = await messaging.getToken();
      if (token != null) {
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .update({
              'fcm_tokens': FieldValue.arrayRemove([token]),
            })
            .timeout(const Duration(seconds: 10));
      } else {
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .delete()
            .timeout(const Duration(seconds: 10));
      }
      await messaging.deleteToken();
      debugPrint('Token unregistered for $cleanEmail');
    } catch (e) {
      debugPrint('Warning: Error unregistering FCM token: $e');
    }
  }

  /// Menampilkan notifikasi lokal untuk email baru yang masuk
  Future<void> showIncomingEmailNotification({
    required String from,
    required String subject,
    String? body,
    String? snippet,
  }) async {
    final senderStr = from;
    final subjectStr = subject;
    final displayBody = (body != null && body.isNotEmpty)
        ? body
        : ((snippet != null && snippet.isNotEmpty) ? snippet : 'Anda menerima email baru');

    final config = _getChannelAndSound(senderStr, subjectStr, null, displayBody);
    final notifId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final notifTag = 'baknus_incoming_email_$notifId';

    String targetRoute = '/home';
    if (config['id'] == 'channel_baknus_attend_v4') {
      targetRoute = '/attend';
    } else if (config['id'] == 'channel_baknus_drive_v4') {
      targetRoute = '/drive';
    } else if (config['id'] == 'channel_baknus_talim_v4') {
      targetRoute = '/talim';
    }

    final payloadMap = {
      'route': targetRoute,
      'email_from': senderStr,
      'subject': subjectStr,
      'notif_title': 'Email dari $senderStr',
      'notif_body': displayBody,
      'channel_id': config['id'],
      'sound_name': config['sound'],
    };

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      config['id']!,
      config['name']!,
      channelDescription: config['desc'],
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(config['sound']!),
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      tag: notifTag,
      groupKey: 'com.baknus.baknusmail.NOTIFICATIONS',
    );

    await _localNotificationsPlugin.show(
      id: notifId,
      title: '📧 Email Baru: $senderStr',
      body: subjectStr.isNotEmpty ? subjectStr : displayBody,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  /// Menampilkan notifikasi lokal ketika email berhasil dikirim ("Kirim Email")
  Future<void> showSentEmailNotification({
    required String to,
    required String subject,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_email_umum_v4',
      'Email Notifications',
      channelDescription: 'Notifikasi email umum & pesan',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('sound_umum'),
      showWhen: true,
      tag: 'baknus_sent_email',
      groupKey: 'com.baknus.baknusmail.NOTIFICATIONS',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final notifId = (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);
    final payloadMap = {
      'route': '/home',
      'title': 'Email Terkirim',
      'body': 'Kepada: $to | Subjek: $subject',
    };

    await _localNotificationsPlugin.show(
      id: notifId,
      title: '✓ Email Terkirim',
      body: 'Kepada: $to\nSubjek: ${subject.isNotEmpty ? subject : "(Tanpa Subjek)"}',
      notificationDetails: platformDetails,
      payload: jsonEncode(payloadMap),
    );
  }

  /// Menampilkan Notifikasi Uji Coba Manual (BaknusAttend / BaknusDrive / BaknusTalim / Email)
  Future<void> showTestNotification(String type) async {
    late RemoteMessage testMessage;
    if (type == 'attend') {
      testMessage = const RemoteMessage(
        data: {
          'route': '/attend',
          'channel_id': 'channel_baknus_attend_v4',
          'sound_name': 'sound_baknus_attend',
          'notif_title': 'BaknusAttend - Presensi Berhasil',
          'notif_body': 'Presensi kehadiran Anda hari ini jam 07:00 WIB telah tercatat!',
        },
      );
    } else if (type == 'drive') {
      testMessage = const RemoteMessage(
        data: {
          'route': '/drive',
          'channel_id': 'channel_baknus_drive_v4',
          'sound_name': 'sound_baknus_drive',
          'notif_title': 'BaknusDrive - Berkas Baru',
          'notif_body': 'File Modul_Pembelajaran_2026.pdf berhasil diunggah.',
        },
      );
    } else if (type == 'talim') {
      testMessage = const RemoteMessage(
        data: {
          'route': '/talim',
          'channel_id': 'channel_baknus_talim_v4',
          'sound_name': 'sound_baknus_talim',
          'notif_title': 'BaknusTalim - Pengumuman Kajian',
          'notif_body': 'Jadwal Kajian Dhuha & Doa Bersama di Masjid BN 666.',
        },
      );
    } else {
      testMessage = const RemoteMessage(
        data: {
          'route': '/home',
          'channel_id': 'channel_email_umum_v4',
          'sound_name': 'sound_umum',
          'notif_title': 'BaknusMail - Email Baru Masuk',
          'notif_body': 'Pengirim: Kepala Sekolah | Subjek: Pengumuman Ujian Semester',
        },
      );
    }

    await _showLocalNotification(testMessage);
  }
}

