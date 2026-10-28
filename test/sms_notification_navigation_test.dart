import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';

void main() {
  group('SMS Notification Navigation & Details Screen Tests', () {
    testWidgets('ScanResultScreen displays masked sender, timestamp, and threat indicators for SMS', (tester) async {
      final mockResult = ScanResult(
        id: 'test-sms-1',
        timestamp: DateTime(2026, 10, 29, 14, 30),
        type: ScanType.sms,
        riskLevel: RiskLevel.critical,
        title: 'Law Enforcement / Digital Arrest Threat',
        description: 'Impersonates CBI cyber police to extort money.',
        warnings: const [
          WarningIndicator(
            title: 'Digital Arrest Coercion',
            description: 'Police never put citizens under digital arrest over SMS or phone call.',
            icon: Icons.gavel,
          ),
        ],
        recommendation: 'Hang up immediately and dial 1930.',
        analysisMethod: AnalysisMethod.mlModel,
        sender: '+919876543210',
        originalInput: 'You are under digital arrest by CBI. Contact immediately.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            result: mockResult,
            scannedInput: mockResult.originalInput!,
          ),
        ),
      );

      // Verify app bar title
      expect(find.text('SMS Analysis Results'), findsOneWidget);

      // Verify threat title and status
      expect(find.text('Law Enforcement / Digital Arrest Threat'), findsOneWidget);
      expect(find.text('BLOCKED'), findsOneWidget);

      // Verify masked sender (middle digits masked)
      expect(find.textContaining('+91 98******10'), findsOneWidget);

      // Verify timestamp
      expect(find.textContaining('2026-10-29 14:30'), findsOneWidget);

      // Verify scanned input text
      expect(find.text('You are under digital arrest by CBI. Contact immediately.'), findsOneWidget);

      // Verify warning indicator
      expect(find.text('Digital Arrest Coercion'), findsOneWidget);

      // Verify recommendation
      expect(find.text('Hang up immediately and dial 1930.'), findsOneWidget);

      // Verify analysis method
      expect(find.text('ML MODEL'), findsOneWidget);
    });

    testWidgets('AutomaticSmsGuardService triggers navigation to ScanResultScreen on notification tap', (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      AutomaticSmsGuardService.onNotificationTapNavigation = (result, scannedInput) {
        navKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              result: result,
              scannedInput: scannedInput,
            ),
          ),
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('SMS Analysis Results'), findsNothing);

      final fakeThreat = ScanResult(
        id: 'tap-1',
        timestamp: DateTime.now(),
        type: ScanType.sms,
        riskLevel: RiskLevel.high,
        title: 'Suspicious Smishing SMS Detected',
        description: 'Contains suspicious KYC link.',
        warnings: const [
          WarningIndicator(
            title: 'Fake Bank KYC Threat',
            description: 'Phishing domain detected.',
            icon: Icons.link,
          ),
        ],
        recommendation: 'Do not click.',
        sender: 'VM-SBINB',
      );

      // Simulate notification tap callback trigger
      AutomaticSmsGuardService.onNotificationTapNavigation?.call(fakeThreat, 'Your SBI KYC is blocked.');
      await tester.pumpAndSettle();

      // Navigation must have pushed ScanResultScreen
      expect(find.text('SMS Analysis Results'), findsOneWidget);
      expect(find.text('Suspicious Smishing SMS Detected'), findsOneWidget);
      expect(find.textContaining('VM-SBINB'), findsOneWidget);

      AutomaticSmsGuardService.onNotificationTapNavigation = null;
    });
  });
}
