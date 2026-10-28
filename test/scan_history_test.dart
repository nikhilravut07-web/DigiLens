import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/scan_history_service.dart';

void main() {
  group('ScanHistoryService & Privacy Sanitization Tests', () {
    final history = ScanHistoryService.instance;

    setUp(() {
      history.clearHistory();
    });

    test('History is memory-only and starts empty after clear', () {
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
  });
}
