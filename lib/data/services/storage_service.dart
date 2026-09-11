import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import '../models/email_message.dart';

class StorageService {
  static const String keyUser = 'baknus_user_session';
  static const String keyThemeMode = 'baknus_theme_mode';
  static const String keySignature = 'baknus_email_signature';
  static const String keyCachedEmails = 'baknus_cached_emails_';
  static const String keySavedDrafts = 'baknus_saved_drafts';
  static const String keyParentMode = 'baknus_is_parent_mode';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // User session
  Future<void> saveUser(UserAccount user) async {
    await _prefs.setString(keyUser, jsonEncode(user.toJson()));
  }

  UserAccount? getUser() {
    final raw = _prefs.getString(keyUser);
    if (raw == null) return null;
    try {
      return UserAccount.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _prefs.remove(keyUser);
  }

  // User Avatar
  static const String keyUserAvatar = 'baknus_user_avatar_';

  Future<void> saveUserAvatar(String email, String base64Avatar) async {
    await _prefs.setString('$keyUserAvatar$email', base64Avatar);
  }

  String? getUserAvatar(String email) {
    return _prefs.getString('$keyUserAvatar$email');
  }

  // Parent Mode
  bool isParentMode() {
    return _prefs.getBool(keyParentMode) ?? false;
  }

  Future<void> setParentMode(bool isParent) async {
    await _prefs.setBool(keyParentMode, isParent);
  }

  // Theme mode: 'light', 'dark', 'system'
  String getThemeMode() {
    return _prefs.getString(keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(keyThemeMode, mode);
  }

  // Signature
  String getSignature(String userEmail) {
    return _prefs.getString(keySignature) ??
        '--\nDikirim melalui BaknusMail\nSMK Bakti Nusantara 666';
  }

  Future<void> setSignature(String signature) async {
    await _prefs.setString(keySignature, signature);
  }

  // Cache emails per user and folder
  Future<void> cacheEmails(String folder, List<EmailMessage> emails, {String? userEmail}) async {
    final emailPrefix = userEmail ?? getUser()?.email ?? 'default';
    final listJson = emails.map((e) => e.toJson()).toList();
    await _prefs.setString('$keyCachedEmails${emailPrefix}_$folder', jsonEncode(listJson));
  }

  List<EmailMessage> getCachedEmails(String folder, {String? userEmail}) {
    final emailPrefix = userEmail ?? getUser()?.email ?? 'default';
    final raw = _prefs.getString('$keyCachedEmails${emailPrefix}_$folder');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => EmailMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Drafts
  Future<void> saveDrafts(List<EmailMessage> drafts) async {
    final listJson = drafts.map((e) => e.toJson()).toList();
    await _prefs.setString(keySavedDrafts, jsonEncode(listJson));
  }

  List<EmailMessage> getDrafts() {
    final raw = _prefs.getString(keySavedDrafts);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => EmailMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Security & App Lock
  static const String keyAppLockEnabled = 'baknus_app_lock_enabled';
  static const String keyAppPin = 'baknus_app_pin_hash';
  static const String keyBiometricEnabled = 'baknus_biometric_enabled';
  static const String keyLockTimeoutSeconds = 'baknus_lock_timeout_seconds';

  bool isAppLockEnabled() {
    return _prefs.getBool(keyAppLockEnabled) ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _prefs.setBool(keyAppLockEnabled, enabled);
  }

  String? getAppPin() {
    return _prefs.getString(keyAppPin);
  }

  Future<void> setAppPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs.remove(keyAppPin);
    } else {
      await _prefs.setString(keyAppPin, pin);
    }
  }

  bool isBiometricEnabled() {
    return _prefs.getBool(keyBiometricEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(keyBiometricEnabled, enabled);
  }

  int getLockTimeoutSeconds() {
    // Default 0: Kunci segera saat app keluar
    return _prefs.getInt(keyLockTimeoutSeconds) ?? 0;
  }

  Future<void> setLockTimeoutSeconds(int seconds) async {
    await _prefs.setInt(keyLockTimeoutSeconds, seconds);
  }

  // BaknusChat Grace Period Settings
  static const String keyChatGraceEnabled = 'baknus_chat_grace_enabled';
  static const String keyChatGraceTimeoutSeconds = 'baknus_chat_grace_timeout_seconds';

  bool isChatGraceEnabled() {
    return _prefs.getBool(keyChatGraceEnabled) ?? true;
  }

  Future<void> setChatGraceEnabled(bool enabled) async {
    await _prefs.setBool(keyChatGraceEnabled, enabled);
  }

  int getChatGraceTimeoutSeconds() {
    // Default 10 menit (600 detik)
    return _prefs.getInt(keyChatGraceTimeoutSeconds) ?? 600;
  }

  Future<void> setChatGraceTimeoutSeconds(int seconds) async {
    await _prefs.setInt(keyChatGraceTimeoutSeconds, seconds);
  }

  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('baknus_cached_emails_') || k == keySavedDrafts);
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
