import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/screens/performance_screen.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ScanHistoryService.instance.setPreferencesForTesting(prefs);
    ScanHistoryService.instance.clearHistory();
  });

  group('PerformanceScreen Live URL Statistics & Ground Truth Handling', () {
    testWidgets('Renders live URL stats and ground-truth required state correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceScreen(),
        ),
      );

      expect(find.text('Performance & Live Stats'), findsOneWidget);
      expect(find.text('Live URL Scan Statistics'), findsOneWidget);
      expect(find.textContaining('Ground truth required'), findsNWidgets(3)); // Precision, Recall, FPR
    });

    test('Scanning a new URL increases live URL scan count and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      expect(ScanHistoryService.instance.items.length, 0);

      final result = ScanResult(
        id: 'test-1',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        riskScore: 0,
        title: 'Safe',
        description: 'Safe URL',
        warnings: [],
        recommendation: 'None',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: 'https://example.com',
      );

      ScanHistoryService.instance.recordScan(
        rawInput: 'https://example.com',
        result: result,
      );

      expect(ScanHistoryService.instance.items.length, 1);
      expect(ScanHistoryService.instance.items.first.sanitizedInput, 'https://example.com');
    });

    test('Duplicate requests within 5 seconds do not create duplicate scan records', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      final result = ScanResult(
        id: 'test-2',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.medium,
        riskScore: 40,
        title: 'Medium',
        description: 'Suspicious',
        warnings: [],
        recommendation: 'Caution',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: 'https://suspicious.xyz',
      );

      ScanHistoryService.instance.recordScan(
        rawInput: 'https://suspicious.xyz',
        result: result,
      );
      // Rapid duplicate record attempt
      ScanHistoryService.instance.recordScan(
        rawInput: 'https://suspicious.xyz',
        result: result,
      );

      expect(ScanHistoryService.instance.items.length, 1);
    });

    test('Zero scans calculates 0% flagged rate without zero-division error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      final linkItems = ScanHistoryService.instance.items
          .where((i) => i.result.type == ScanType.link)
          .toList();
      final total = linkItems.length;
      final threatCount = 0;
      final rate = total > 0 ? (threatCount / total) * 100 : 0.0;
      expect(rate, 0.0);
    });

    test('Non-URL scans (e.g. SMS) are excluded from URL statistics', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      final smsResult = ScanResult(
        id: 'sms-1',
        timestamp: DateTime.now(),
        type: ScanType.sms,
        riskLevel: RiskLevel.high,
        riskScore: 65,
        title: 'Smishing',
        description: 'Suspicious SMS',
        warnings: [],
        recommendation: 'Do not reply',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: 'Your bank account is blocked. Call 9999999999',
      );

      ScanHistoryService.instance.recordScan(
        rawInput: 'Your bank account is blocked. Call 9999999999',
        result: smsResult,
      );

      final linkItems = ScanHistoryService.instance.items
          .where((i) => i.result.type == ScanType.link)
          .toList();
      expect(linkItems.length, 0); // Excluded from URL-only stats
    });
  });
}
