import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Architecture Protection Test', () {
    test('Verifikasi eksistensi file sound_umum.mp3 di res/raw', () {
      final soundFile = File('android/app/src/main/res/raw/sound_umum.mp3');
      expect(soundFile.existsSync(), isTrue,
          reason: 'File sound_umum.mp3 wajib ada di android/app/src/main/res/raw/');
      expect(soundFile.lengthSync(), greaterThan(1000),
          reason: 'Ukuran file sound_umum.mp3 tidak boleh kosong');
    });

    test('Verifikasi channel_email_umum_v4 di AndroidManifest.xml', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();
      expect(content.contains('channel_email_umum_v4'), isTrue,
          reason: 'com.google.firebase.messaging.default_notification_channel_id wajib channel_email_umum_v4');
    });

    test('Verifikasi channel_email_umum_v4 dan sound_umum di fcm_service.dart', () {
      final fcmFile = File('lib/data/services/fcm_service.dart');
      expect(fcmFile.existsSync(), isTrue);
      final content = fcmFile.readAsStringSync();
      expect(content.contains('channel_email_umum_v4'), isTrue,
          reason: 'fcm_service.dart wajib mendaftarkan channel_email_umum_v4');
      expect(content.contains('sound_umum'), isTrue,
          reason: 'fcm_service.dart wajib menggunakan sound_umum');
    });

    test('Verifikasi background sync dan showIncomingEmailNotification di mail_provider.dart', () {
      final mailProviderFile = File('lib/providers/mail_provider.dart');
      expect(mailProviderFile.existsSync(), isTrue);
      final content = mailProviderFile.readAsStringSync();
      expect(content.contains('_knownEmailIds'), isTrue,
          reason: 'mail_provider.dart wajib memiliki pelacak _knownEmailIds');
      expect(content.contains('syncNewEmailsInBackground'), isTrue,
          reason: 'mail_provider.dart wajib memiliki fungsi syncNewEmailsInBackground');
      expect(content.contains('showIncomingEmailNotification'), isTrue,
          reason: 'mail_provider.dart wajib memicu showIncomingEmailNotification');
    });
  });
}
