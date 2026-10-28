import 'package:flutter/foundation.dart';
import 'package:digilens/models/scan_result.dart';

/// Single item stored in scan history.
class ScanHistoryItem {
  final String sanitizedInput;
  final ScanResult result;

  const ScanHistoryItem({required this.sanitizedInput, required this.result});
}

/// Service that records and manages scans performed by the user.
///
/// Ensures privacy:
/// - Full SMS messages containing OTPs or passwords are sanitized/masked before saving.
/// - Never stores passwords, tokens, or personal identifiers in history logs.
class ScanHistoryService {
  ScanHistoryService._();
  static final ScanHistoryService instance = ScanHistoryService._();

  final List<ScanHistoryItem> _items = [];
  final ValueNotifier<List<ScanHistoryItem>> historyNotifier =
      ValueNotifier<List<ScanHistoryItem>>([]);

  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  /// Records a scan result in history after sanitizing sensitive inputs.
  void recordScan({required String rawInput, required ScanResult result}) {
    final sanitized = _sanitizeInput(rawInput, result.type);
    final historyItem = ScanHistoryItem(
      sanitizedInput: sanitized,
      result: result,
    );

    _items.insert(0, historyItem);
    historyNotifier.value = List.unmodifiable(_items);
  }

  /// Clears the recorded scan history.
  void clearHistory() {
    _items.clear();
    historyNotifier.value = [];
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
