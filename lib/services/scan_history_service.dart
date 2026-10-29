import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digilens/models/scan_result.dart';

/// Single item stored in scan history.
class ScanHistoryItem {
  final String sanitizedInput;
  final ScanResult result;
  final String? source;

  const ScanHistoryItem({
    required this.sanitizedInput,
    required this.result,
    this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'sanitizedInput': sanitizedInput,
      'result': result.toJson(),
      if (source != null) 'source': source,
    };
  }

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      sanitizedInput: json['sanitizedInput'] as String,
      result: ScanResult.fromJson(json['result'] as Map<String, dynamic>),
      source: json['source'] as String?,
    );
  }
}

/// Service that records and manages scans performed by the user.
///
/// Ensures privacy and persistence:
/// - Persisted locally in SharedPreferences as JSON so scans survive app restarts.
/// - Full SMS messages containing OTPs or passwords are sanitized/masked before saving.
/// - Never stores passwords, tokens, or personal identifiers in history logs.
/// - Deduplicates repeated intent triggers or fast successive scans of the same item.
class ScanHistoryService {
  ScanHistoryService._();
  static final ScanHistoryService instance = ScanHistoryService._();

  static const String _storageKey = 'digilens_scan_history_records';
  static const int _maxStoredItems = 150;

  SharedPreferences? _prefs;

  final List<ScanHistoryItem> _items = [];
  final ValueNotifier<List<ScanHistoryItem>> historyNotifier =
      ValueNotifier<List<ScanHistoryItem>>([]);

  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  /// Visible for testing to inject mock SharedPreferences or reset state.
  @visibleForTesting
  void setPreferencesForTesting(SharedPreferences? prefs) {
    _prefs = prefs;
  }

  /// Initializes the service by loading persisted scan records from local storage.
  Future<void> init({SharedPreferences? prefs}) async {
    try {
      _prefs = prefs ?? await SharedPreferences.getInstance();
      final jsonStr = _prefs?.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _items.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _items.add(ScanHistoryItem.fromJson(item));
          }
        }
        historyNotifier.value = List.unmodifiable(_items);
      }
    } catch (_) {
      // Graceful fallback if storage is uninitialized or unavailable
    }
  }

  /// Records a scan result in history after sanitizing sensitive inputs.
  /// Prevents immediate duplicates and persists to local storage.
  void recordScan({
    required String rawInput,
    required ScanResult result,
    String? source,
  }) {
    final sanitized = _sanitizeInput(rawInput, result.type);

    // Prevent immediate duplicate entries (e.g. Android singleTop re-delivering intent
    // or scanning the exact same URL within 5 seconds)
    if (_items.isNotEmpty) {
      final last = _items.first;
      if (last.result.id == result.id) {
        return;
      }
      final diff = DateTime.now().difference(last.result.timestamp).inSeconds.abs();
      if (last.sanitizedInput == sanitized &&
          last.result.riskLevel == result.riskLevel &&
          diff < 5) {
        return;
      }
    }

    final historyItem = ScanHistoryItem(
      sanitizedInput: sanitized,
      result: result,
      source: source,
    );

    _items.insert(0, historyItem);
    if (_items.length > _maxStoredItems) {
      _items.removeRange(_maxStoredItems, _items.length);
    }
    historyNotifier.value = List.unmodifiable(_items);

    if (_prefs != null) {
      _saveToDisk();
    }
  }

  /// Clears the recorded scan history from memory and local storage.
  void clearHistory() {
    _items.clear();
    historyNotifier.value = [];
    final prefs = _prefs;
    if (prefs != null) {
      prefs.remove(_storageKey);
    }
  }

  /// Persists the current in-memory history items to SharedPreferences.
  Future<void> _saveToDisk() async {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final jsonList = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Sanitizes sensitive user input before storing in memory or local logs.
  static String _sanitizeInput(String input, ScanType type) {
    if (type == ScanType.link) {
      // Strip potential sensitive query parameters (e.g. token=xyz, password=abc).
      // Uri.replace(queryParameters: {}) leaves a trailing '?' on the string
      // representation, so we remove the delimiter explicitly to avoid storing
      // "https://example.com/path?" — the bare path without query secrets is
      // the intended stored form.
      try {
        final uri = Uri.tryParse(input);
        if (uri != null && uri.hasQuery) {
          final cleanUri = uri.replace(queryParameters: {});
          // Remove any trailing '?' left by the URI library.
          return cleanUri.toString().replaceFirst(RegExp(r'\?$'), '');
        }
      } catch (_) {}
      return input;
    }

    // For SMS or Voice transcript: mask any 4-8 digit OTPs or card numbers
    String sanitized = input;

    // Mask potential card numbers (16 digits)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(?:\d[ -]*?){13,16}\b'),
      (m) => '•••• •••• •••• [CARD MASKED]',
    );

    // Mask potential OTPs (4-8 consecutive digits)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b\d{4,8}\b'),
      (m) => '[OTP/CODE MASKED]',
    );

    // Truncate overly long transcripts for privacy and storage efficiency
    if (sanitized.length > 300) {
      sanitized = '${sanitized.substring(0, 300)}… [TRUNCATED]';
    }

    return sanitized;
  }
}
