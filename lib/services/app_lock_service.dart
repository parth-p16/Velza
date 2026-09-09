import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService extends ChangeNotifier {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _prefLockEnabled = 'app_lock_enabled';
  static const String _prefPinHash = 'app_lock_pin_hash';
  static const String _prefPinSalt = 'app_lock_pin_salt';
  static const String _prefBiometricEnabled = 'app_lock_biometric_enabled';
  static const String _prefTimeoutSetting = 'app_lock_timeout_setting'; // 'immediately', '1_min', '5_min', '15_min'

  bool _isLockEnabled = false;
  bool _isBiometricEnabled = false;
  String _timeoutSetting = 'immediately';
  bool _isCurrentlyLocked = false;
  DateTime? _lastPausedTime;
  bool _isAuthenticating = false;

  bool get isLockEnabled => _isLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get timeoutSetting => _timeoutSetting;
  bool get isCurrentlyLocked => _isCurrentlyLocked;
  bool get isAuthenticating => _isAuthenticating;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool(_prefLockEnabled) ?? false;
    _isBiometricEnabled = prefs.getBool(_prefBiometricEnabled) ?? false;
    _timeoutSetting = prefs.getString(_prefTimeoutSetting) ?? 'immediately';

    if (_isLockEnabled) {
      _isCurrentlyLocked = true;
    }
    notifyListeners();
  }

  Duration _getTimeoutDuration(String setting) {
    switch (setting) {
      case '1_min':
        return const Duration(minutes: 1);
      case '5_min':
        return const Duration(minutes: 5);
      case '15_min':
        return const Duration(minutes: 15);
      case 'immediately':
      default:
        return Duration.zero;
    }
  }

  void onAppPaused() {
    if (!_isLockEnabled || _isAuthenticating) return;
    _lastPausedTime = DateTime.now();
    if (_timeoutSetting == 'immediately') {
      _isCurrentlyLocked = true;
      notifyListeners();
    }
  }

  void onAppResumed() {
    if (!_isLockEnabled || _isAuthenticating) return;
    if (_lastPausedTime != null) {
      final elapsed = DateTime.now().difference(_lastPausedTime!);
      final allowedGrace = _getTimeoutDuration(_timeoutSetting);
      if (elapsed >= allowedGrace) {
        _isCurrentlyLocked = true;
        notifyListeners();
      }
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!isDeviceSupported && !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricEnabled || _isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock Velza',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        unlock();
        return true;
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    } finally {
      _isAuthenticating = false;
    }
    return false;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:velza_luxury_salt_2026');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<bool> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_prefPinHash);
    final storedSalt = prefs.getString(_prefPinSalt);
    if (storedHash == null || storedSalt == null) return false;

    final computedHash = _hashPin(enteredPin, storedSalt);
    if (computedHash == storedHash) {
      unlock();
      return true;
    }
    return false;
  }

  Future<void> setupPin({
    required String pin,
    required bool enableBiometrics,
    String timeout = 'immediately',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await prefs.setBool(_prefLockEnabled, true);
    await prefs.setString(_prefPinHash, hash);
    await prefs.setString(_prefPinSalt, salt);
    await prefs.setBool(_prefBiometricEnabled, enableBiometrics);
    await prefs.setString(_prefTimeoutSetting, timeout);

    _isLockEnabled = true;
    _isBiometricEnabled = enableBiometrics;
    _timeoutSetting = timeout;
    _isCurrentlyLocked = false;
    notifyListeners();
  }

  Future<void> disableLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLockEnabled);
    await prefs.remove(_prefPinHash);
    await prefs.remove(_prefPinSalt);
    await prefs.remove(_prefBiometricEnabled);
    await prefs.remove(_prefTimeoutSetting);

    _isLockEnabled = false;
    _isBiometricEnabled = false;
    _isCurrentlyLocked = false;
    notifyListeners();
  }

  Future<void> updateTimeoutSetting(String newSetting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTimeoutSetting, newSetting);
    _timeoutSetting = newSetting;
    notifyListeners();
  }

  Future<void> updateBiometricSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefBiometricEnabled, enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  void unlock() {
    _isCurrentlyLocked = false;
    _lastPausedTime = null;
    notifyListeners();
  }

  void lockNow() {
    if (_isLockEnabled) {
      _isCurrentlyLocked = true;
      notifyListeners();
    }
  }

  void onUserSignOut() {
    _isCurrentlyLocked = false;
    _lastPausedTime = null;
    notifyListeners();
  }
}
