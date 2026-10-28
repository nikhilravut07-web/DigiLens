import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing parental control settings, PIN setup, verification,
/// lockout enforcement, and local parental activity history.
class ParentalControlService {
  static final ParentalControlService instance = ParentalControlService._internal();
  ParentalControlService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Storage keys
  static const String _pinKey = 'digilens_parental_pin';
  static const String _enabledKey = 'digilens_parental_enabled';
  static const String _failedAttemptsKey = 'digilens_parental_failed_attempts';
  static const String _lockoutUntilKey = 'digilens_parental_lockout_until';
  static const String _historyKey = 'digilens_parental_history';

  // In-memory cache for rapid synchronous checks
  bool _isEnabled = false;
  String? _cachedPin;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  List<ParentalActivityRecord> _history = [];

  bool get isEnabled => _isEnabled;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;
  List<ParentalActivityRecord> get history => List.unmodifiable(_history);

  /// Initialize service state from secure and local storage.
  Future<void> init() async {
    try {
      _cachedPin = await _secureStorage.read(key: _pinKey);
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledKey) ?? false;
      _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
      final lockoutStr = prefs.getString(_lockoutUntilKey);
      if (lockoutStr != null) {
        _lockoutUntil = DateTime.tryParse(lockoutStr);
        // Reset lockout if expired
        if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
          _lockoutUntil = null;
          _failedAttempts = 0;
          await prefs.remove(_lockoutUntilKey);
          await prefs.setInt(_failedAttemptsKey, 0);
        }
      }

      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _history = decoded
            .map((e) => ParentalActivityRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Graceful handling of corrupted/unavailable storage
      _cachedPin = null;
      _isEnabled = false;
      _failedAttempts = 0;
      _lockoutUntil = null;
      _history = [];
    }
  }

  /// Check if a 6-digit PIN has been configured.
  Future<bool> hasPinSet() async {
    if (_cachedPin != null && _cachedPin!.isNotEmpty) return true;
    try {
      _cachedPin = await _secureStorage.read(key: _pinKey);
      return _cachedPin != null && _cachedPin!.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Set or update the 6-digit parental PIN.
  Future<bool> setPin(String pin) async {
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return false;
    }
    try {
      await _secureStorage.write(key: _pinKey, value: pin);
      _cachedPin = pin;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verify entered PIN with lockout protection.
  /// Returns [PinVerificationResult].
  Future<PinVerificationResult> verifyPin(String enteredPin) async {
    // 1. Check if currently locked out
    if (_lockoutUntil != null) {
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        return PinVerificationResult.lockedOut;
      } else {
        // Lockout expired
        _lockoutUntil = null;
        _failedAttempts = 0;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lockoutUntilKey);
        await prefs.setInt(_failedAttemptsKey, 0);
      }
    }

    final validPin = await hasPinSet() ? _cachedPin : null;
    if (validPin == null) {
      return PinVerificationResult.noPinSet;
    }

    if (enteredPin == validPin) {
      // Reset failed attempts on success
      _failedAttempts = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_failedAttemptsKey, 0);
      await prefs.remove(_lockoutUntilKey);
      _lockoutUntil = null;
      return PinVerificationResult.success;
    } else {
      _failedAttempts++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_failedAttemptsKey, _failedAttempts);

      // Lock out for 30 seconds after 3 failed attempts
      if (_failedAttempts >= 3) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        await prefs.setString(_lockoutUntilKey, _lockoutUntil!.toIso8601String());
        await recordActivity(
          eventType: 'pin_lockout',
          details: 'Temporarily locked out after 3 failed PIN attempts',
          status: 'blocked',
        );
        return PinVerificationResult.lockedOut;
      }

      await recordActivity(
        eventType: 'pin_verification',
        details: 'Incorrect PIN attempt ($_failedAttempts/3)',
        status: 'failed',
      );
      return PinVerificationResult.incorrect;
    }
  }

  /// Enable or disable parental controls (requires prior PIN verification by caller).
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await recordActivity(
      eventType: 'parental_status_change',
      details: enabled ? 'Parental Controls enabled' : 'Parental Controls disabled',
      status: enabled ? 'approved' : 'cancelled',
    );
  }

  /// Record an event in local parental activity history.
  Future<void> recordActivity({
    required String eventType,
    required String details,
    required String status, // 'approved', 'cancelled', 'blocked', 'failed'
    String? targetUrl,
  }) async {
    final record = ParentalActivityRecord(
      timestamp: DateTime.now(),
      eventType: eventType,
      details: details,
      status: status,
      targetUrl: targetUrl,
    );

    _history.insert(0, record);
    // Keep max 100 history items
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((e) => e.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Clear activity history.
  Future<void> clearHistory() async {
    _history.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }

  /// Reset all parental control data (for testing / demo reset).
  Future<void> resetAll() async {
    _isEnabled = false;
    _cachedPin = null;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _history.clear();
    try {
      await _secureStorage.delete(key: _pinKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_enabledKey);
      await prefs.remove(_failedAttemptsKey);
      await prefs.remove(_lockoutUntilKey);
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}

enum PinVerificationResult {
  success,
  incorrect,
  lockedOut,
  noPinSet,
}

class ParentalActivityRecord {
  final DateTime timestamp;
  final String eventType; // 'website_access', 'pin_verification', 'parental_status_change', etc.
  final String details;
  final String status; // 'approved', 'cancelled', 'blocked', 'failed'
  final String? targetUrl;

  ParentalActivityRecord({
    required this.timestamp,
    required this.eventType,
    required this.details,
    required this.status,
    this.targetUrl,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'details': details,
        'status': status,
        'targetUrl': targetUrl,
      };

  factory ParentalActivityRecord.fromJson(Map<String, dynamic> json) =>
      ParentalActivityRecord(
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: json['eventType'] as String,
        details: json['details'] as String,
        status: json['status'] as String,
        targetUrl: json['targetUrl'] as String?,
      );
}
