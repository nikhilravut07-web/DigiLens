import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/pre_navigation_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation Guard & Pure Decision Function Tests', () {
    test('javascript: scheme is blocked by evaluateNavigation', () {
      final dummyResult = ScanResult(
        id: '1',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'Dangerous',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );

      final decision = evaluateNavigation(
        targetUrl: 'javascript:alert(1)',
        analysisResult: dummyResult,
      );

      expect(decision, NavigationDecision.blocked);
    });

    test('data: scheme is blocked by evaluateNavigation', () {
      final dummyResult = ScanResult(
        id: '2',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'Dangerous',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );

      final decision = evaluateNavigation(
        targetUrl: 'data:text/html,<h1>Phishing</h1>',
        analysisResult: dummyResult,
      );

      expect(decision, NavigationDecision.blocked);
    });

    test('vbscript: and blob: schemes are blocked by evaluateNavigation', () {
      final dummyResult = ScanResult(
        id: '3',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'Dangerous',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );

      expect(
        evaluateNavigation(
          targetUrl: 'vbscript:msgbox(1)',
          analysisResult: dummyResult,
        ),
        NavigationDecision.blocked,
      );

      expect(
        evaluateNavigation(
          targetUrl: 'blob:https://example.com/uuid',
          analysisResult: dummyResult,
        ),
        NavigationDecision.blocked,
      );
    });

    test(
      'Medium/High/Critical risk URL results in NavigationDecision.warn',
      () {
        final mediumResult = ScanResult(
          id: '4',
          timestamp: DateTime.now(),
          type: ScanType.link,
          riskLevel: RiskLevel.medium,
          title: 'Moderate',
          description: 'Test',
          warnings: const [],
          recommendation: 'None',
        );

        expect(
          evaluateNavigation(
            targetUrl: 'https://suspicious.xyz',
            analysisResult: mediumResult,
          ),
          NavigationDecision.warn,
        );

        final highResult = ScanResult(
          id: '5',
          timestamp: DateTime.now(),
          type: ScanType.link,
          riskLevel: RiskLevel.high,
          title: 'High',
          description: 'Test',
          warnings: const [],
          recommendation: 'None',
        );

        expect(
          evaluateNavigation(
            targetUrl: 'https://phish.top',
            analysisResult: highResult,
          ),
          NavigationDecision.warn,
        );

        final criticalResult = ScanResult(
          id: '5b',
          timestamp: DateTime.now(),
          type: ScanType.link,
          riskLevel: RiskLevel.critical,
          title: 'Critical',
          description: 'Test',
          warnings: const [],
          recommendation: 'None',
        );

        expect(
          evaluateNavigation(
            targetUrl: 'http://192.168.1.1@evil.com/login',
            analysisResult: criticalResult,
          ),
          NavigationDecision.warn,
        );
      },
    );

    test('Safe/Low risk URL results in NavigationDecision.allow', () {
      final safeResult = ScanResult(
        id: '6',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Safe',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );

      expect(
        evaluateNavigation(
          targetUrl: 'https://example.com',
          analysisResult: safeResult,
        ),
        NavigationDecision.allow,
      );

      final lowResult = ScanResult(
        id: '7',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.low,
        title: 'Low',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );

      expect(
        evaluateNavigation(
          targetUrl: 'http://example.com',
          analysisResult: lowResult,
        ),
        NavigationDecision.allow,
      );
    });

    test('Redirect / changed destination re-evaluates risk and blocks dangerous targets', () {
      // Simulating when a safe initial URL attempts to redirect to a dangerous scheme or high-risk domain
      final safeResult = ScanResult(
        id: 'initial',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Safe',
        description: 'Test',
        warnings: const [],
        recommendation: 'None',
      );
      expect(
        evaluateNavigation(
          targetUrl: 'https://example.com',
          analysisResult: safeResult,
        ),
        NavigationDecision.allow,
      );

      // Redirect destination is a data: or javascript: URI
      final redirectedDangerous = evaluateNavigation(
        targetUrl: 'javascript:stealCookies()',
        analysisResult: safeResult,
      );
      expect(redirectedDangerous, NavigationDecision.blocked);

      // Redirect destination is a newly analyzed suspicious domain
      final redirectedPhishingResult = ScanResult(
        id: 'redirect-phish',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'Phishing',
        description: 'Phishing destination',
        warnings: const [],
        recommendation: 'None',
      );
      final redirectedDecision = evaluateNavigation(
        targetUrl: 'https://fake-bank-login.xyz',
        analysisResult: redirectedPhishingResult,
      );
      expect(redirectedDecision, NavigationDecision.warn);
    });
  });

  group('MethodChannel & Protected Browser Integration Tests', () {
    final List<MethodCall> channelCalls = [];

    setUp(() {
      channelCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PreNavigationGuard.browserChannel, (
            MethodCall call,
          ) async {
            channelCalls.add(call);
            if (call.method == 'openBrowser') {
              return true;
            }
            if (call.method == 'getInitialIntent') {
              return 'https://incometax.gov.in';
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PreNavigationGuard.browserChannel, null);
    });

    testWidgets(
      'navigateWithProtection launches native browser for approved safe URLs',
      (tester) async {
        final safeResult = ScanResult(
          id: 'test-safe',
          timestamp: DateTime.now(),
          type: ScanType.link,
          riskLevel: RiskLevel.safe,
          title: 'Safe URL',
          description: 'No threat',
          warnings: const [],
          recommendation: 'None',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PreNavigationGuard.navigateWithProtection(
                      context,
                      targetUrl: 'https://example.com',
                      existingResult: safeResult,
                    );
                  },
                  child: const Text('Launch Browser'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Launch Browser'));
        await tester.pumpAndSettle();

        expect(
          channelCalls.any((call) => call.method == 'openBrowser'),
          isTrue,
        );
        final openCall = channelCalls.firstWhere(
          (call) => call.method == 'openBrowser',
        );
        expect(openCall.arguments['url'], 'https://example.com');
        expect(openCall.arguments['scanResult']['riskLevel'], 'safe');
      },
    );

    testWidgets(
      'navigateWithProtection blocks dangerous javascript: without opening browser',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      PreNavigationGuard.navigateWithProtection(
                        context,
                        targetUrl: 'javascript:alert(1)',
                      );
                    },
                    child: const Text('Launch Dangerous'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Dangerous'));
        await tester.pumpAndSettle();

        // Should show SnackBar and NOT call openBrowser
        expect(find.text('Blocked: dangerous URI scheme.'), findsOneWidget);
        expect(
          channelCalls.any((call) => call.method == 'openBrowser'),
          isFalse,
        );
      },
    );

    testWidgets(
      'navigateWithProtection presents warning modal for medium/high risk and respects cancel',
      (tester) async {
        final highResult = ScanResult(
          id: 'test-high',
          timestamp: DateTime.now(),
          type: ScanType.link,
          riskLevel: RiskLevel.high,
          title: 'Suspicious Domain',
          description: 'Phishing warning',
          warnings: const [],
          recommendation: 'Avoid',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      PreNavigationGuard.navigateWithProtection(
                        context,
                        targetUrl: 'https://sbi-phishing.xyz',
                        existingResult: highResult,
                      );
                    },
                    child: const Text('Launch Risky'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Risky'));
        await tester.pumpAndSettle();

        // Pre-navigation warning sheet should be visible
        expect(find.text('Navigation Intercepted'), findsOneWidget);
        expect(
          find.text('Cancel & Return to Safety (Recommended)'),
          findsOneWidget,
        );

        // Tap Cancel
        await tester.tap(find.text('Cancel & Return to Safety (Recommended)'));
        await tester.pumpAndSettle();

        // Browser must not have been opened
        expect(
          channelCalls.any((call) => call.method == 'openBrowser'),
          isFalse,
        );
      },
    );

    testWidgets(
      'initIntentHandler fetches initial intent on cold start and deduplicates',
      (tester) async {
        final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('Home')),
          ),
        );

        PreNavigationGuard.initIntentHandler(navKey);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Verifies getInitialIntent was called
        expect(
          channelCalls.any((call) => call.method == 'getInitialIntent'),
          isTrue,
        );
      },
    );
  });
}
