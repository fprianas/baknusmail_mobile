import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/security_service.dart';

class SecurityProvider extends ChangeNotifier {
  final StorageService _storageService;
  final SecurityService _securityService;

  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  int _lockTimeoutSeconds = 0;
  bool _isLocked = false;

  bool _isDeviceSupported = false;
  bool _canCheckBiometrics = false;
  String _biometricLabel = 'Biometrik HP';

  // State untuk Toleransi Khusus BaknusChat
  bool _isInChat = false;
  bool _isChatGraceEnabled = true;
  int _chatGraceTimeoutSeconds = 600;

  // Cegah auto-lock saat dialog biometrik sistem Android dibuka
  bool _isAuthenticating = false;
  DateTime? _lastAuthCompleteTime;
  DateTime? _lastBackgroundTime;

  SecurityProvider(this._storageService, this._securityService) {
    _init();
  }

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isLocked => _isLocked;
  bool get hasPin => _storageService.getAppPin() != null && _storageService.getAppPin()!.isNotEmpty;
  bool get isDeviceSupported => _isDeviceSupported;
  bool get canCheckBiometrics => _canCheckBiometrics;
  bool get isAuthenticating => _isAuthenticating;
  String get biometricLabel => _biometricLabel;
  bool get isInChat => _isInChat;
  bool get isChatGraceEnabled => _isChatGraceEnabled;
  int get chatGraceTimeoutSeconds => _chatGraceTimeoutSeconds;

  Future<void> _init() async {
    _isAppLockEnabled = _storageService.isAppLockEnabled();
    _isBiometricEnabled = _storageService.isBiometricEnabled();
    _lockTimeoutSeconds = _storageService.getLockTimeoutSeconds();
    _isChatGraceEnabled = _storageService.isChatGraceEnabled();
    _chatGraceTimeoutSeconds = _storageService.getChatGraceTimeoutSeconds();

    // Catatan: _isLocked akan diaktifkan secara mulus setelah splash screen selesai
    // atau ketika aplikasi resume dari latar belakang (background)

    try {
      _isDeviceSupported = await _securityService.isDeviceSupported();
      _canCheckBiometrics = await _securityService.canCheckBiometrics();
      _biometricLabel = await _securityService.getBiometricLabel();
    } catch (_) {
      _isDeviceSupported = false;
      _canCheckBiometrics = false;
    }

    notifyListeners();
  }

  /// Aktifkan / Nonaktifkan Kunci Aplikasi
  Future<void> setAppLockEnabled(bool enabled) async {
    _isAppLockEnabled = enabled;
    await _storageService.setAppLockEnabled(enabled);
    if (!enabled) {
      _isLocked = false;
    }
    notifyListeners();
  }

  /// Atur PIN 6 Digit Baru
  Future<void> setPin(String pin) async {
    final hashed = _securityService.hashPin(pin);
    await _storageService.setAppPin(hashed);
    notifyListeners();
  }

  /// Hapus PIN (ketika menonaktifkan app lock)
  Future<void> clearPin() async {
    await _storageService.setAppPin(null);
    await _storageService.setAppLockEnabled(false);
    await _storageService.setBiometricEnabled(false);
    _isAppLockEnabled = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  /// Verifikasi PIN
  bool verifyPin(String inputPin) {
    final storedHash = _storageService.getAppPin();
    return _securityService.verifyPin(inputPin, storedHash);
  }

  /// Toggle Biometrik
  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabled = enabled;
    await _storageService.setBiometricEnabled(enabled);
    notifyListeners();
  }

  /// Waktu jeda kunci otomatis (detik)
  Future<void> setLockTimeoutSeconds(int seconds) async {
    _lockTimeoutSeconds = seconds;
    await _storageService.setLockTimeoutSeconds(seconds);
    notifyListeners();
  }

  /// Buka kunci
  void unlock() {
    if (_isLocked) {
      _isLocked = false;
      notifyListeners();
    }
  }

  /// Kunci manual
  void lock() {
    if (_isAppLockEnabled && hasPin && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Memicu prompt biometrik
  Future<BiometricAuthResult> authenticateWithBiometrics({
    String reason = 'Gunakan biometrik untuk membuka BaknusMail',
  }) async {
    if (_isAuthenticating) {
      return const BiometricAuthResult(
        success: false,
        errorMessage: 'Proses verifikasi sedang berjalan.',
      );
    }

    _isAuthenticating = true;
    try {
      final result = await _securityService.authenticateBiometrics(reason: reason);
      if (result.success) {
        unlock();
      }
      return result;
    } finally {
      _lastAuthCompleteTime = DateTime.now();
      // Berikan jeda waktu agar transisi resume dari dialog sistem Android selesai diproses
      Future.delayed(const Duration(milliseconds: 1200), () {
        _isAuthenticating = false;
      });
    }
  }

  /// Update status apakah user sedang membuka BaknusChat
  void setInChat(bool inChat) {
    if (_isInChat != inChat) {
      _isInChat = inChat;
      notifyListeners();
    }
  }

  /// Aktifkan / Nonaktifkan toleransi khusus saat di BaknusChat
  Future<void> setChatGraceEnabled(bool enabled) async {
    _isChatGraceEnabled = enabled;
    await _storageService.setChatGraceEnabled(enabled);
    notifyListeners();
  }

  /// Atur durasi batas toleransi chat (detik)
  Future<void> setChatGraceTimeoutSeconds(int seconds) async {
    _chatGraceTimeoutSeconds = seconds;
    await _storageService.setChatGraceTimeoutSeconds(seconds);
    notifyListeners();
  }

  /// Lifecycle: Saat aplikasi masuk ke background
  void onAppPaused() {
    // Jangan set background time jika pause dipicu oleh dialog biometrik sistem Android
    if (_isAuthenticating) return;
    _lastBackgroundTime = DateTime.now();
  }

  /// Lifecycle: Saat aplikasi kembali ke foreground
  void onAppResumed() {
    // Abaikan lifecycle resume jika dipicu oleh penutupan prompt biometrik Android
    if (_isAuthenticating) return;
    if (_lastAuthCompleteTime != null &&
        DateTime.now().difference(_lastAuthCompleteTime!).inMilliseconds < 1500) {
      return;
    }

    if (!_isAppLockEnabled || !hasPin) return;

    // Jika user sedang berada di halaman obrolan dan fitur toleransi chat aktif,
    // gunakan durasi toleransi chat (misal 10 menit) alih-alih durasi normal.
    final effectiveTimeout = (_isInChat && _isChatGraceEnabled)
        ? _chatGraceTimeoutSeconds
        : _lockTimeoutSeconds;

    if (_lastBackgroundTime != null) {
      final elapsedSeconds = DateTime.now().difference(_lastBackgroundTime!).inSeconds;
      if (elapsedSeconds >= effectiveTimeout) {
        lock();
      }
    } else {
      if (!(_isInChat && _isChatGraceEnabled)) {
        lock();
      }
    }
  }
}
