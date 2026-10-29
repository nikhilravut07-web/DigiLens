import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/scan_history_service.dart';

void main() {
  group('ScanHistoryService & Privacy Sanitization Tests', () {
    final history = ScanHistoryService.instance;

    setUp(() {
      history.setPreferencesForTesting(null);
      history.clearHistory();
    });

    test('History starts empty after clear', () {
      expect(history.items, isEmpty);
    });

    test('OTPs (4-8 digits) are masked in stored SMS history', () {
      final result = ScanResult(
        id: 'test-1',
        timestamp: DateTime.now(),
        type: ScanType.sms,
        riskLevel: RiskLevel.high,
        title: 'SMS Alert',
        description: 'Test description',
        warnings: const [],
        recommendation: 'Test rec',
        analysisMethod: AnalysisMethod.localHeuristics,
      );

      history.recordScan(
        rawInput: 'Your secret OTP is 482910 for transaction.',
        result: result,
      );

      expect(history.items.length, 1);
      final stored = history.items.first.sanitizedInput;
      expect(stored, isNot(contains('482910')));
      expect(stored, contains('[OTP/CODE MASKED]'));
    });

    test('Card numbers (16 digits) are masked in stored SMS history', () {
      final result = ScanResult(
        id: 'test-2',
        timestamp: DateTime.now(),
        type: ScanType.sms,
        riskLevel: RiskLevel.high,
        title: 'Card Alert',
        description: 'Test description',
        warnings: const [],
        recommendation: 'Test rec',
        analysisMethod: AnalysisMethod.localHeuristics,
      );

      history.recordScan(
        rawInput: 'Card 4111222233334444 has been blocked.',
        result: result,
      );

      expect(history.items.length, 1);
      final stored = history.items.first.sanitizedInput;
      expect(stored, isNot(contains('4111222233334444')));
      expect(stored, contains('[CARD MASKED]'));
    });

    test('URL query parameters are stripped from stored link history', () {
      final result = ScanResult(
        id: 'test-3',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.medium,
        title: 'Link Alert',
        description: 'Test description',
        warnings: const [],
        recommendation: 'Test rec',
        analysisMethod: AnalysisMethod.localHeuristics,
      );

      history.recordScan(
        rawInput: 'https://example.com/reset?token=secret_auth_token_123',
        result: result,
      );

      expect(history.items.length, 1);
      final stored = history.items.first.sanitizedInput;
      expect(stored, isNot(contains('secret_auth_token_123')));
      // Query stripped completely without trailing '?'
      expect(stored, equals('https://example.com/reset'));
    });

    test('Records source app metadata (e.g. WhatsApp) correctly', () {
      final result = ScanResult(
        id: 'test-source-1',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'WhatsApp Link',
        description: 'Test',
        warnings: const [],
        recommendation: 'Test',
      );

      history.recordScan(
        rawInput: 'https://whatsapp.com/sample',
        result: result,
        source: 'WhatsApp',
      );

      expect(history.items.length, 1);
      expect(history.items.first.source, equals('WhatsApp'));
    });

    test('Deduplicates rapid successive scans of the same input and risk level', () {
      final now = DateTime.now();
      final result1 = ScanResult(
        id: 'dedup-1',
        timestamp: now,
        type: ScanType.link,
        riskLevel: RiskLevel.high,
        title: 'Scam Link',
        description: 'Test',
        warnings: const [],
        recommendation: 'Test',
      );
      final result2 = ScanResult(
        id: 'dedup-2',
        timestamp: now.add(const Duration(milliseconds: 100)),
        type: ScanType.link,
        riskLevel: RiskLevel.high,
        title: 'Scam Link',
        description: 'Test',
        warnings: const [],
        recommendation: 'Test',
      );

      history.recordScan(
        rawInput: 'https://scam-bank.xyz',
        result: result1,
        source: 'SMS',
      );
      history.recordScan(
        rawInput: 'https://scam-bank.xyz',
        result: result2,
        source: 'SMS',
      );

      expect(history.items.length, 1);
    });
  });

  group('ScanHistoryService Persistence Tests', () {
    final history = ScanHistoryService.instance;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      history.clearHistory();
    });

    test('Persists recorded scans and restores on init()', () async {
      await history.init();
      history.clearHistory();

      final result = ScanResult(
        id: 'persist-1',
        timestamp: DateTime(2026, 3, 1, 10, 0),
        type: ScanType.link,
        riskLevel: RiskLevel.medium,
        title: 'Persisted Link Scan',
        description: 'Test persist',
        warnings: const [],
        recommendation: 'Be cautious',
      );

      history.recordScan(
        rawInput: 'https://suspicious-promo.xyz/deal',
        result: result,
        source: 'WhatsApp',
      );

      expect(history.items.length, 1);
      expect(history.items.first.source, 'WhatsApp');

      // Re-initialize to simulate application restart
      await history.init();

      expect(history.items.length, 1);
      final restored = history.items.first;
      expect(restored.sanitizedInput, 'https://suspicious-promo.xyz/deal');
      expect(restored.result.title, 'Persisted Link Scan');
      expect(restored.result.riskLevel, RiskLevel.medium);
      expect(restored.source, 'WhatsApp');
    });

    test('clearHistory removes persisted records from storage', () async {
      await history.init();
      final result = ScanResult(
        id: 'persist-clear',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Test',
        description: 'Test',
        warnings: const [],
        recommendation: 'Safe',
      );

      history.recordScan(rawInput: 'https://example.com', result: result);
      expect(history.items.length, 1);

      history.clearHistory();
      expect(history.items, isEmpty);

      // Reloading from storage must remain empty
      await history.init();
      expect(history.items, isEmpty);
    });
  });
}
