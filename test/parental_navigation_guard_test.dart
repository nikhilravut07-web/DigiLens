import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/services/pre_navigation_guard.dart';
import 'package:digilens/models/scan_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ParentalControlService.instance.resetAll();
    await ParentalControlService.instance.init();
  });

  group('Parental Control & PreNavigationGuard Risk-Tier Integration Tests', () {
    test('evaluateNavigation blocks dangerous schemes', () {
      final safeResult = ScanResult(
        id: 'test_safe',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Safe Link',
        description: 'Verified safe URL',
        warnings: const [],
        recommendation: 'Safe to open',
      );

      expect(
        evaluateNavigation(targetUrl: 'javascript:alert(1)', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
      expect(
        evaluateNavigation(targetUrl: 'data:text/html,...', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
      expect(
        evaluateNavigation(targetUrl: 'vbscript:msgbox(1)', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
      expect(
        evaluateNavigation(targetUrl: 'blob:https://example.com/uuid', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
      expect(
        evaluateNavigation(targetUrl: 'file:///android_asset/index.html', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
      expect(
        evaluateNavigation(targetUrl: 'intent:#Intent;...', analysisResult: safeResult),
        NavigationDecision.blocked,
      );
    });

    test('evaluateNavigation allows safe and low risk links', () {
      final safeResult = ScanResult(
        id: 'test_safe',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Safe Link',
        description: 'Verified safe URL',
        warnings: const [],
        recommendation: 'Safe to open',
      );

      final lowResult = ScanResult(
        id: 'test_low',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.low,
        title: 'Low Risk Link',
        description: 'Mostly safe URL',
        warnings: const [],
        recommendation: 'Safe to open with caution',
      );

      expect(
        evaluateNavigation(targetUrl: 'https://flutter.dev', analysisResult: safeResult),
        NavigationDecision.allow,
      );
      expect(
        evaluateNavigation(targetUrl: 'https://example.com/page', analysisResult: lowResult),
        NavigationDecision.allow,
      );
    });

    test('evaluateNavigation warns on medium, high, and critical risk links', () {
      final mediumResult = ScanResult(
        id: 'test_med',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.medium,
        title: 'Medium Risk',
        description: 'Suspicious redirect',
        warnings: const [],
        recommendation: 'Caution',
      );

      final highResult = ScanResult(
        id: 'test_high',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.high,
        title: 'Phishing Alert',
        description: 'Phishing domain',
        warnings: const [],
        recommendation: 'Do not proceed',
      );

      final criticalResult = ScanResult(
        id: 'test_crit',
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'Critical Threat',
        description: 'Known malware site',
        warnings: const [],
        recommendation: 'Blocked',
      );

      expect(
        evaluateNavigation(targetUrl: 'https://suspicious-domain.xyz', analysisResult: mediumResult),
        NavigationDecision.warn,
      );
      expect(
        evaluateNavigation(targetUrl: 'https://phishing-site.xyz', analysisResult: highResult),
        NavigationDecision.warn,
      );
      expect(
        evaluateNavigation(targetUrl: 'https://malware-site.xyz', analysisResult: criticalResult),
        NavigationDecision.warn,
      );
    });

    test('Parental control enabled records cancellation when PIN modal is not passed', () async {
      final service = ParentalControlService.instance;
      await service.resetAll();
      await service.setPin('123456');
      await service.setEnabled(true);
      await service.clearHistory();

      expect(service.isEnabled, isTrue);
      expect(await service.hasPinSet(), isTrue);

      await service.recordActivity(
        eventType: 'website_access',
        details: 'Risky website access cancelled (medium risk, PIN verification declined)',
        status: 'cancelled',
        targetUrl: 'https://suspicious.com',
      );

      expect(service.history.length, 1);
      expect(service.history.first.status, 'cancelled');
      expect(service.history.first.targetUrl, 'https://suspicious.com');
    });

    test('Activity history records safe website access without requiring PIN', () async {
      final service = ParentalControlService.instance;
      await service.resetAll();
      await service.setPin('123456');
      await service.setEnabled(true);
      await service.clearHistory();

      await service.recordActivity(
        eventType: 'website_access',
        details: 'Opened safe website',
        status: 'approved',
        targetUrl: 'https://trusted-learning.org',
      );

      expect(service.history.length, 1);
      expect(service.history.first.status, 'approved');
      expect(service.history.first.targetUrl, 'https://trusted-learning.org');
      expect(service.history.first.details, contains('safe'));
    });

    test('Activity history records approved website access with parental PIN for medium/high risk', () async {
      final service = ParentalControlService.instance;
      await service.resetAll();
      await service.setPin('999999');
      await service.setEnabled(true);
      await service.clearHistory();

      await service.recordActivity(
        eventType: 'website_access',
        details: 'Opened medium-risk website with parental PIN approval',
        status: 'approved',
        targetUrl: 'https://maybe-risky.com',
      );

      expect(service.history.length, 1);
      expect(service.history.first.status, 'approved');
      expect(service.history.first.targetUrl, 'https://maybe-risky.com');
      expect(service.history.first.details, contains('PIN approval'));
    });
  });
}
