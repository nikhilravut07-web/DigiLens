import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digilens/services/parental_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ParentalControlService.instance.resetAll();
    await ParentalControlService.instance.init();
  });

  group('ParentalControlService PIN Management & Lockout Tests', () {
    test('Initial state: no PIN set, disabled, 0 failed attempts', () async {
      final service = ParentalControlService.instance;
      expect(await service.hasPinSet(), isFalse);
      expect(service.isEnabled, isFalse);
      expect(service.failedAttempts, 0);
      expect(service.lockoutUntil, isNull);
      expect(service.history, isEmpty);
    });

    test('Rejects invalid PIN formats (non-6-digit)', () async {
      final service = ParentalControlService.instance;
      expect(await service.setPin('12345'), isFalse);
      expect(await service.setPin('1234567'), isFalse);
      expect(await service.setPin('abcdef'), isFalse);
      expect(await service.hasPinSet(), isFalse);
    });

    test('Successfully sets and verifies 6-digit PIN', () async {
      final service = ParentalControlService.instance;
      final setSuccess = await service.setPin('123456');
      expect(setSuccess, isTrue);
      expect(await service.hasPinSet(), isTrue);

      final result = await service.verifyPin('123456');
      expect(result, PinVerificationResult.success);
      expect(service.failedAttempts, 0);
    });

    test('Incorrect PIN increments failed attempts and returns incorrect', () async {
      final service = ParentalControlService.instance;
      await service.setPin('654321');

      final result = await service.verifyPin('111111');
      expect(result, PinVerificationResult.incorrect);
      expect(service.failedAttempts, 1);
    });

    test('3 failed attempts triggers temporary lockout', () async {
      final service = ParentalControlService.instance;
      await service.setPin('987654');

      expect(await service.verifyPin('000000'), PinVerificationResult.incorrect);
      expect(service.failedAttempts, 1);

      expect(await service.verifyPin('000001'), PinVerificationResult.incorrect);
      expect(service.failedAttempts, 2);

      // Third failed attempt triggers lockout
      final thirdAttempt = await service.verifyPin('000002');
      expect(thirdAttempt, PinVerificationResult.lockedOut);
      expect(service.failedAttempts, 3);
      expect(service.lockoutUntil, isNotNull);
      expect(service.lockoutUntil!.isAfter(DateTime.now()), isTrue);

      // Even correct PIN during lockout returns lockedOut
      final lockedAttempt = await service.verifyPin('987654');
      expect(lockedAttempt, PinVerificationResult.lockedOut);
    });

    test('Enabling and disabling parental control updates state and logs history', () async {
      final service = ParentalControlService.instance;
      await service.setPin('123456');

      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);
      expect(service.history.first.eventType, 'parental_status_change');
      expect(service.history.first.status, 'approved');

      await service.setEnabled(false);
      expect(service.isEnabled, isFalse);
      expect(service.history.first.eventType, 'parental_status_change');
      expect(service.history.first.status, 'cancelled');
    });

    test('Activity history records events and can be cleared', () async {
      final service = ParentalControlService.instance;
      await service.recordActivity(
        eventType: 'website_access',
        details: 'Attempted access to https://example.com',
        status: 'blocked',
        targetUrl: 'https://example.com',
      );

      expect(service.history.length, 1);
      expect(service.history.first.targetUrl, 'https://example.com');
      expect(service.history.first.status, 'blocked');

      await service.clearHistory();
      expect(service.history, isEmpty);
    });

    test('Persistence across init() reloads enabled state and history', () async {
      final service = ParentalControlService.instance;
      await service.setPin('555555');
      await service.setEnabled(true);
      await service.recordActivity(
        eventType: 'website_access',
        details: 'https://test.org',
        status: 'approved',
        targetUrl: 'https://test.org',
      );

      // Re-initialize service
      await service.init();
      expect(service.isEnabled, isTrue);
      expect(await service.hasPinSet(), isTrue);
      expect(service.history.length, 2); // 1 from setEnabled + 1 website_access
    });
  });
}
