import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';
import 'package:digilens/services/scan_history_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Automatic Incoming SMS Scam Detection Test Suite (14 Scenarios)', () {
    late AutomaticSmsGuardService guardService;

    setUp(() {
      guardService = AutomaticSmsGuardService.instance;
      guardService.setProtectionEnabled(true);
      guardService.setCloudAiEnabled(true);
      ScanHistoryService.instance.clearHistory();
    });

    // 1. Fake bank KYC / PAN block SMS with phishing link
    test('1. Fake bank KYC / PAN block SMS with phishing link is flagged high/critical', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'critical',
              'risk_score': 95,
              'scam_type': 'fake_kyc',
              'evidence': [
                {'title': 'Fake Bank KYC Threat', 'description': 'Threat to block SBI account'}
              ],
              'recommended_action': 'Do not click links. Contact SBI branch.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'VM-SBINB',
        body: 'Dear customer, your SBI account is blocked due to pending KYC. Click http://sbi-update.xyz to verify.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, RiskLevel.critical);
      expect(res.riskScore, 95);
      expect(res.title, contains('KYC'));
    });

    // 2. Urgent electricity disconnection threat with personal phone number
    test('2. Urgent electricity disconnection threat with personal phone number flags utility extortion', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'high',
              'risk_score': 80,
              'scam_type': 'utility_threat',
              'evidence': [
                {'title': 'Utility Disconnection Threat', 'description': 'Fake electricity disconnection notice'}
              ],
              'recommended_action': 'Do not call 9876543210. Contact your power discom.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'Unknown',
        body: 'URGENT: Your electricity power will be disconnected tonight at 9:30 PM due to unpaid bill. Call officer at 9876543210 immediately.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(res.title, contains('Utility'));
    });

    // 3. Fake lottery / prize winning SMS
    test('3. Fake lottery / prize winning SMS flags advance-fee scam', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'critical',
              'risk_score': 90,
              'scam_type': 'lottery_scam',
              'evidence': [
                {'title': 'Advance-Fee Prize Scam', 'description': 'Unearned lottery prize claim'}
              ],
              'recommended_action': 'Delete message. Never send advance processing fees.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'VK-PRIZE',
        body: 'Congratulations! Your mobile number won Rs. 25,00,000 in KBC Lucky Draw. Send bank details to claim.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, RiskLevel.critical);
      expect(res.title, contains('Lottery'));
    });

    // 4. Digital arrest / law enforcement extortion SMS
    test('4. Digital arrest / law enforcement extortion SMS flags extortion threat', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'critical',
              'risk_score': 99,
              'scam_type': 'digital_arrest',
              'evidence': [
                {'title': 'Digital Arrest Extortion', 'description': 'CBI warrant extortion'}
              ],
              'recommended_action': 'Disconnect and dial 1930 immediately.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'CBI-CYBER',
        body: 'Arrest warrant issued by CBI Cyber Crime. You are under digital arrest. Click to join immediate hearing.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, RiskLevel.critical);
      expect(res.title, contains('Digital Arrest'));
    });

    // 5. Explicit request to share an OTP
    test('5. Explicit request to share OTP flags active credential harvesting', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'critical',
              'risk_score': 90,
              'scam_type': 'otp_theft',
              'evidence': [
                {'title': 'OTP Credential Theft', 'description': 'Active request to disclose OTP'}
              ],
              'recommended_action': 'Never disclose OTP to anyone.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AX-HDFC',
        body: 'Your card has a pending international charge. Share this OTP 481920 with customer executive to cancel.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
    });

    // 6. Legitimate bank transaction alert with debit details and reference number
    test('6. Legitimate bank transaction alert is classified as safe or low risk', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'safe',
              'risk_score': 0,
              'scam_type': 'unknown',
              'evidence': [],
              'recommended_action': 'Verify unexpected transactions in your official banking app.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AD-HDFCBK',
        body: 'Rs 450.00 debited from A/C **1234 on 29-OCT at Swiggy. Ref No 491028301. If not done by you, call 18002583838.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, RiskLevel.safe);
      expect(res.riskScore, 0);
    });

    // 7. Legitimate bank security advisory ("Do not share your OTP")
    test('7. Legitimate security advisory warning NOT to share OTP is safe', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'safe',
              'risk_score': 0,
              'scam_type': 'unknown',
              'evidence': [],
              'recommended_action': 'Keep OTP confidential.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AD-SBIBNK',
        body: 'Security Alert: State Bank of India never asks for your OTP, PIN, or CVV. Never share your OTP with anyone.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, RiskLevel.safe);
    });

    // 8. Legitimate OTP delivery message
    test('8. Legitimate OTP delivery message is not classified as a malicious scam', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'safe',
              'risk_score': 5,
              'scam_type': 'unknown',
              'evidence': [],
              'recommended_action': 'Use OTP only on official login portal.',
            }),
            200,
          );
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AX-AMAZON',
        body: '482910 is your Amazon verification OTP. Valid for 10 minutes. Do not share it with anyone.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.safe, RiskLevel.low]));
    });

    // 9. Multipart SMS assembled into single message
    test('9. Multipart SMS concatenated message is analyzed in its complete context', () async {
      // Simulate multipart segment combination
      const segment1 = 'Dear user, your electricity account #849102 has an unpaid bill of Rs 1,420. ';
      const segment2 = 'Power supply will be disconnected tonight at 9:30 PM. Call our helpline at 9876543210 to avoid disconnection.';
      const combined = segment1 + segment2;

      guardService.setCloudAiEnabled(false); // Local heuristic fallback
      final res = await guardService.processIncomingSms(
        sender: 'Unknown',
        body: combined,
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(res.warnings.any((w) => w.title.contains('Utility')), isTrue);
    });

    // 10. Duplicate SMS received in rapid succession is deduplicated
    test('10. Duplicate SMS received in rapid succession is deduplicated and not reprocessed', () async {
      guardService.setCloudAiEnabled(false);
      const text = 'Urgent: Your SBI account suspended. Click http://sbi-fake.xyz';

      final res1 = await guardService.processIncomingSms(sender: 'SBI-ALERT', body: text);
      expect(res1, isNotNull);

      // Second identical incoming broadcast
      final res2 = await guardService.processIncomingSms(sender: 'SBI-ALERT', body: text);
      expect(res2, isNull, reason: 'Duplicate SMS should be skipped by deduplication filter');
    });

    // 11. Backend unavailable falls back to local heuristic detection
    test('11. Backend unavailable (connection error) falls back cleanly to local heuristics', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          throw Exception('Connection refused / backend offline');
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AX-BANK',
        body: 'Dear customer, your bank account is blocked due to KYC. Update now at http://bank-kyc.xyz',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(res.analysisMethod, AnalysisMethod.localHeuristics);
    });

    // 12. Backend returns HTTP 429 quota exhaustion falls back to local heuristics
    test('12. Backend HTTP 429 quota exhaustion falls back gracefully to local heuristics', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          return http.Response('{"error": "Resource exhausted / quota exceeded"}', 429);
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'VK-WIN',
        body: 'Congratulations! You won Rs 10,00,000 cash in lottery. Send details.',
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.medium, RiskLevel.high, RiskLevel.critical]));
      expect(res.analysisMethod, AnalysisMethod.localHeuristics);
    });

    // 13. Protection toggle disabled causes incoming SMS to be ignored
    test('13. Protection toggle disabled causes incoming SMS to be ignored completely', () async {
      guardService.setProtectionEnabled(false);

      final res = await guardService.processIncomingSms(
        sender: 'VK-SCAM',
        body: 'Your account is blocked. Click http://scam.xyz',
      );

      expect(res, isNull);
    });

    // 14. Sensitive data (OTP, credit card numbers) masked in ScanHistoryService
    test('14. Sensitive data (OTP, card numbers) is masked before history persistence', () async {
      guardService.setCloudAiEnabled(false);
      const rawWithSensitive = 'Your card 4532 1192 8847 2819 charge is pending. Your OTP is 928371. Share immediately.';

      await guardService.processIncomingSms(
        sender: 'FakeBank',
        body: rawWithSensitive,
      );

      final history = ScanHistoryService.instance.items;
      expect(history.isNotEmpty, isTrue);

      final storedInput = history.first.sanitizedInput;
      // Sensitive card number and OTP must be masked
      expect(storedInput, contains('CARD MASKED'));
      expect(storedInput, contains('OTP/CODE MASKED'));
      expect(storedInput, isNot(contains('4532 1192 8847 2819')));
      expect(storedInput, isNot(contains('928371')));
    });

    // 15. Notification tap with fromTap: true forces analysis even if background protection toggle is off
    test('15. Notification tap forces analysis even when background protection is disabled', () async {
      guardService.setProtectionEnabled(false);
      guardService.setCloudAiEnabled(false);

      final res = await guardService.processIncomingSms(
        sender: 'VM-SBI',
        body: 'Your account is blocked. Update KYC immediately.',
        fromTap: true,
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
    });

    // 16. Notification tap navigation callback receives scan result and original text
    test('16. Notification tap navigation callback receives valid scan result with sender and text', () async {
      guardService.setCloudAiEnabled(false);
      ScanResult? capturedResult;
      String? capturedInput;

      AutomaticSmsGuardService.onNotificationTapNavigation = (result, input) {
        capturedResult = result;
        capturedInput = input;
      };

      const testBody = 'URGENT: Power disconnected tonight. Call 9876543210.';
      const testSender = '+919876543210';

      final res = await guardService.processIncomingSms(
        sender: testSender,
        body: testBody,
        fromTap: true,
      );

      // Trigger navigation callback as done on notification tap
      if (res != null) {
        AutomaticSmsGuardService.onNotificationTapNavigation?.call(res, testBody);
      }

      expect(capturedResult, isNotNull);
      expect(capturedResult!.sender, testSender);
      expect(capturedInput, testBody);
      expect(capturedResult!.warnings.isNotEmpty, isTrue);

      AutomaticSmsGuardService.onNotificationTapNavigation = null;
    });

    // 17. ScanResult stores originating sender and timestamp for SMS threat inspection
    test('17. ScanResult accurately records originating sender and scan timestamp', () async {
      guardService.setCloudAiEnabled(false);
      const senderNum = '+919876543210';
      const bodyText = 'Arrest warrant issued by CBI Cyber Cell. Digital arrest in effect.';

      final res = await guardService.processIncomingSms(
        sender: senderNum,
        body: bodyText,
      );

      expect(res, isNotNull);
      expect(res!.sender, senderNum);
      expect(res.timestamp, isNotNull);
      expect(res.type, ScanType.sms);
    });

    // 18. Analysis engine exception falls back to resilient fallback ScanResult
    test('18. Error in cloud analysis safely falls back to local heuristic scan result', () async {
      guardService.configure(
        client: MockHttpClient((req) async {
          throw Exception('Fatal socket exception');
        }),
      );

      final res = await guardService.processIncomingSms(
        sender: 'AX-WARN',
        body: 'Urgent: Verify your KYC at http://phish.xyz',
        fromTap: true,
      );

      expect(res, isNotNull);
      expect(res!.riskLevel, isIn([RiskLevel.medium, RiskLevel.high, RiskLevel.critical]));
      expect(res.analysisMethod, AnalysisMethod.localHeuristics);
    });
  });
}
