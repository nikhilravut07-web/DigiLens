import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/services/qr_payload_service.dart';
import 'package:digilens/services/url_analysis_service.dart';
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

  group('QR Payload Classifier & URL Validation Tests', () {
    test('Classifies standard HTTP and HTTPS URLs correctly', () {
      final payload1 = QrPayloadClassifier.classify('https://example.com/login?user=1');
      expect(payload1.type, QrPayloadType.url);
      expect(payload1.isWebUrl, true);
      expect(payload1.url, 'https://example.com/login?user=1');

      final payload2 = QrPayloadClassifier.classify('http://malicious-phish.xyz/secure');
      expect(payload2.type, QrPayloadType.url);
      expect(payload2.isWebUrl, true);
      expect(payload2.url, 'http://malicious-phish.xyz/secure');
    });

    test('Classifies domain names without scheme as URLs with HTTPS applied', () {
      final payload = QrPayloadClassifier.classify('www.india.gov.in');
      expect(payload.type, QrPayloadType.url);
      expect(payload.isWebUrl, true);
      expect(payload.url, 'https://www.india.gov.in');
    });

    test('Classifies dangerous non-HTTP URI schemes correctly', () {
      final payload1 = QrPayloadClassifier.classify('javascript:alert(1)');
      expect(payload1.type, QrPayloadType.unsupportedScheme);
      expect(payload1.isWebUrl, false);

      final payload2 = QrPayloadClassifier.classify('data:text/html,<script>alert(1)</script>');
      expect(payload2.type, QrPayloadType.unsupportedScheme);
      expect(payload2.isWebUrl, false);

      final payload3 = QrPayloadClassifier.classify('file:///android_asset/secret.txt');
      expect(payload3.type, QrPayloadType.unsupportedScheme);
      expect(payload3.isWebUrl, false);
    });

    test('Classifies unsupported app schemes safely without executing', () {
      final payload = QrPayloadClassifier.classify('market://details?id=com.example');
      expect(payload.type, QrPayloadType.unsupportedScheme);
      expect(payload.isWebUrl, false);
    });

    test('Identifies and catches malformed URLs', () {
      final payload1 = QrPayloadClassifier.classify('http://');
      expect(payload1.type, QrPayloadType.malformedUrl);
      expect(payload1.isWebUrl, false);

      final payload2 = QrPayloadClassifier.classify('https://   ');
      expect(payload2.type, QrPayloadType.malformedUrl);
      expect(payload2.isWebUrl, false);
    });

    test('Classifies Wi-Fi credentials correctly', () {
      final payload = QrPayloadClassifier.classify('WIFI:S:HomeNetwork;T:WPA;P:secret123;;');
      expect(payload.type, QrPayloadType.wifi);
      expect(payload.isWebUrl, false);
    });

    test('Classifies email and phone numbers correctly', () {
      final emailPayload = QrPayloadClassifier.classify('mailto:support@example.com');
      expect(emailPayload.type, QrPayloadType.email);
      expect(emailPayload.isWebUrl, false);

      final phonePayload = QrPayloadClassifier.classify('tel:+919876543210');
      expect(phonePayload.type, QrPayloadType.phone);
      expect(phonePayload.isWebUrl, false);
    });

    test('Classifies SMS and Geo payloads correctly', () {
      final smsPayload = QrPayloadClassifier.classify('smsto:123456:Hello');
      expect(smsPayload.type, QrPayloadType.sms);
      expect(smsPayload.isWebUrl, false);

      final geoPayload = QrPayloadClassifier.classify('geo:37.7749,-122.4194');
      expect(geoPayload.type, QrPayloadType.geo);
      expect(geoPayload.isWebUrl, false);
    });

    test('Classifies plain text and empty string correctly', () {
      final payload = QrPayloadClassifier.classify('Just some random text note inside QR');
      expect(payload.type, QrPayloadType.plainText);
      expect(payload.isWebUrl, false);

      final emptyPayload = QrPayloadClassifier.classify('   ');
      expect(emptyPayload.type, QrPayloadType.plainText);
      expect(emptyPayload.isWebUrl, false);
    });
  });

  group('QR Scanned URL Analysis & History Integration Tests', () {
    test('QR extracted URL passes through UrlAnalysisService and records to history', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      final qrUrl = 'https://sbi-update-kyc.xyz/login';
      final payload = QrPayloadClassifier.classify(qrUrl);
      expect(payload.isWebUrl, true);

      final result = await UrlAnalysisService.analyzeUrl(payload.url!);
      expect(result.type, ScanType.link);
      expect(result.riskLevel, isNot(RiskLevel.safe)); // Flags suspicious domain/keywords

      // Record to history with QR Scanner source
      ScanHistoryService.instance.recordScan(
        rawInput: payload.url!,
        result: result,
        source: 'QR Scanner',
      );

      expect(ScanHistoryService.instance.items.length, 1);
      final item = ScanHistoryService.instance.items.first;
      expect(item.source, 'QR Scanner');
      expect(item.result.type, ScanType.link);
    });

    test('Duplicate scans of the same QR URL within 5s are deduplicated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ScanHistoryService.instance.init(prefs: prefs);

      const qrUrl = 'https://example.com/page';
      final result = await UrlAnalysisService.analyzeUrl(qrUrl);

      ScanHistoryService.instance.recordScan(rawInput: qrUrl, result: result, source: 'QR Scanner');
      ScanHistoryService.instance.recordScan(rawInput: qrUrl, result: result, source: 'QR Scanner');

      expect(ScanHistoryService.instance.items.length, 1);
    });
  });
}
