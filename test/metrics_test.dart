import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/services/sms_analysis_service.dart';
import 'package:digilens/services/voice_analysis_service.dart';

// ------------------------------------------------------------------
// WARNING: All examples in this file are SYNTHETIC (artificially
// constructed for testing). They do NOT represent real websites,
// real SMS messages, or real phone conversations. Metrics reported
// are based on this synthetic dataset and must NOT be interpreted as
// real-world phishing detection accuracy.
// ------------------------------------------------------------------

/// Classification threshold: riskLevel >= medium counts as a positive
/// threat prediction (flagged as likely fraudulent or suspicious).
/// riskLevel of safe or low counts as a negative (likely legitimate).
///
/// RiskLevel enum order (ascending danger):
///   safe=0, low=1, medium=2, high=3, critical=4
///
/// Positive (threat detected): riskLevel >= medium (index >= 2)
/// Negative (likely legitimate): riskLevel <= low (index <= 1)
bool _isPositive(RiskLevel level) => level.index >= RiskLevel.medium.index;

/// Compute and print synthetic metrics for a detector group.
///
/// RATIONALE FOR THRESHOLDS:
/// - False-Positive Rate (FPR) threshold < 40% ensures that heuristic rules
///   do not excessively block legitimate benign traffic when encountering
///   unencrypted HTTP or uncommon TLD structures.
Map<String, dynamic> _computeMetrics({
  required String label,
  required List<({String input, bool expectMalicious, String description})>
  cases,
  required List<RiskLevel> results,
}) {
  int tp = 0, fp = 0, tn = 0, fn = 0;
  for (int i = 0; i < cases.length; i++) {
    final predicted = _isPositive(results[i]);
    final actual = cases[i].expectMalicious;
    if (actual && predicted) tp++;
    if (!actual && predicted) fp++;
    if (!actual && !predicted) tn++;
    if (actual && !predicted) fn++;
  }

  final precision = (tp + fp) > 0 ? tp / (tp + fp) : 0.0;
  final recall = (tp + fn) > 0 ? tp / (tp + fn) : 0.0;
  final f1 = (precision + recall) > 0
      ? 2 * precision * recall / (precision + recall)
      : 0.0;
  final accuracy = cases.isNotEmpty ? (tp + tn) / cases.length : 0.0;
  final fpr = (fp + tn) > 0 ? fp / (fp + tn) : 0.0;

  // ignore: avoid_print
  print(
    '\n=== SYNTHETIC METRICS: $label ===\n'
    '  Dataset size : ${cases.length} samples '
    '(${cases.where((c) => c.expectMalicious).length} confirmed malicious/threat, '
    '${cases.where((c) => !c.expectMalicious).length} legitimate/benign)\n'
    '  TP=$tp  FP=$fp  TN=$tn  FN=$fn\n'
    '  Precision : ${(precision * 100).toStringAsFixed(1)}%\n'
    '  Recall    : ${(recall * 100).toStringAsFixed(1)}%\n'
    '  F1 Score  : ${(f1 * 100).toStringAsFixed(1)}%\n'
    '  Accuracy  : ${(accuracy * 100).toStringAsFixed(1)}%\n'
    '  False-Pos : ${(fpr * 100).toStringAsFixed(1)}%\n'
    '(SYNTHETIC dataset only — not real-world detection accuracy)\n'
    '===',
  );

  return {
    'tp': tp,
    'fp': fp,
    'tn': tn,
    'fn': fn,
    'precision': precision,
    'recall': recall,
    'f1': f1,
    'accuracy': accuracy,
    'fpr': fpr,
  };
}

void main() {
  // ===========================================================================
  // URL ANALYSIS — INDIVIDUAL REGRESSION TESTS
  // ===========================================================================
  group('URL Analysis — Individual Regression Tests (Synthetic)', () {
    test(
      'javascript: scheme → critical (pre-parse dangerous scheme)',
      () async {
        final r = await UrlAnalysisService.analyzeUrl(
          'javascript:alert("phishing")',
        );
        expect(
          r.riskLevel,
          RiskLevel.critical,
          reason:
              'javascript: is an executable non-HTTP scheme. '
              'Got: ${r.riskLevel}, Score: ${r.riskScore}',
        );
      },
    );

    test('data: scheme → critical (pre-parse dangerous scheme)', () async {
      final r = await UrlAnalysisService.analyzeUrl(
        'data:text/html,<script>steal()</script>',
      );
      expect(
        r.riskLevel,
        RiskLevel.critical,
        reason:
            'data: is a dangerous non-HTTP scheme. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('@ in URL: google.com@phishing-site.ru → critical', () async {
      final r = await UrlAnalysisService.analyzeUrl(
        'https://google.com@phishing-site.ru',
      );
      expect(
        r.riskLevel,
        RiskLevel.critical,
        reason:
            '"@" in URL is the credential-prefix trick. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('paypa1-secure-login.com → high (typosquatting 1→l)', () async {
      final r = await UrlAnalysisService.analyzeUrl(
        'https://paypa1-secure-login.com/update',
      );
      expect(
        r.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.high.index),
        reason:
            'paypa1 is a lookalike for paypal via 1→l substitution. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('incometax-refund-gov.in → high (gov.in impersonation)', () async {
      final r = await UrlAnalysisService.analyzeUrl(
        'https://incometax-refund-gov.in',
      );
      expect(
        r.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.high.index),
        reason:
            'incometax brand used in domain but not on official incometax.gov.in. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('sbi.co.in → safe (official SBI domain, no false positive)', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://sbi.co.in');
      expect(
        r.riskLevel.index,
        lessThanOrEqualTo(RiskLevel.low.index),
        reason:
            'sbi.co.in is an official SBI domain. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('onlinesbi.sbi → safe (official SBI subdomain)', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://onlinesbi.sbi');
      expect(
        r.riskLevel.index,
        lessThanOrEqualTo(RiskLevel.low.index),
        reason:
            'onlinesbi.sbi is an official SBI internet banking domain. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('hdfcbank.com → safe (official HDFC domain)', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://hdfcbank.com');
      expect(
        r.riskLevel.index,
        lessThanOrEqualTo(RiskLevel.low.index),
        reason:
            'hdfcbank.com is the official HDFC Bank domain. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('incometax.gov.in → safe (official government domain)', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://incometax.gov.in');
      expect(
        r.riskLevel.index,
        lessThanOrEqualTo(RiskLevel.low.index),
        reason:
            'incometax.gov.in is the official income tax portal. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('https://google.com → safe', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://google.com');
      expect(
        r.riskLevel.index,
        lessThanOrEqualTo(RiskLevel.low.index),
        reason:
            'google.com is a known legitimate HTTPS site. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });

    test('bit.ly shortener → medium (suspicious indicator / hides destination, not confirmed malicious)', () async {
      final r = await UrlAnalysisService.analyzeUrl('https://bit.ly/3abcxyz');
      expect(
        r.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.medium.index),
        reason:
            'URL shorteners should be flagged as at least medium-risk '
            'due to hidden destination. Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
      expect(
        r.riskLevel,
        isNot(RiskLevel.critical),
        reason:
            'A shortener alone is a suspicious indicator, not critical malice.',
      );
    });

    test('IP address URL → medium (suspicious indicator)', () async {
      final r = await UrlAnalysisService.analyzeUrl(
        'https://192.168.1.100/login',
      );
      expect(
        r.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.medium.index),
        reason:
            'Raw IP address is suspicious. '
            'Got: ${r.riskLevel}, Score: ${r.riskScore}',
      );
    });
  });

  // ===========================================================================
  // URL ANALYSIS — SYNTHETIC REGRESSION SUITE + METRICS
  // ===========================================================================
  group('URL Analysis — Synthetic Regression Suite + Metrics', () {
    // Note: Shorteners (bit.ly), raw IPs, and punycode are categorized as
    // suspicious indicators rather than confirmed malicious ground truth,
    // as they have legitimate administrative/marketing uses.
    final cases = <({String input, bool expectMalicious, String description})>[
      // CONFIRMED MALICIOUS / PHISHING / EXECUTABLE
      (
        input: 'https://sbi-secure-login-verify.xyz/login',
        expectMalicious: true,
        description: 'SBI impersonation + .xyz TLD',
      ),
      (
        input: 'https://paypa1-secure-login.com/update',
        expectMalicious: true,
        description: 'PayPal typosquatting (1→l homoglyph)',
      ),
      (
        input: 'http://secure-login-hdfc-bank.top/account',
        expectMalicious: true,
        description: 'HTTP + .top TLD + brand keywords',
      ),
      (
        input: 'https://hdfcbank.com.scam-site.ru/login',
        expectMalicious: true,
        description: 'Brand in domain, real TLD is .ru',
      ),
      (
        input: 'https://login.secure.sbi.verify.host.evil.xyz',
        expectMalicious: true,
        description: 'Excessive subdomain + brand + .xyz',
      ),
      (
        input: 'https://incometax-refund-gov.in',
        expectMalicious: true,
        description: 'gov.in impersonation',
      ),
      (
        input: 'https://google.com@phishing-site.ru',
        expectMalicious: true,
        description: '@ credential-prefix trick',
      ),
      (
        input: 'javascript:alert("phishing")',
        expectMalicious: true,
        description: 'javascript: scheme (executable)',
      ),
      (
        input: 'data:text/html,<script>steal()</script>',
        expectMalicious: true,
        description: 'data: scheme (executable payload)',
      ),
      // LEGITIMATE / BENIGN
      (
        input: 'https://google.com',
        expectMalicious: false,
        description: 'Well-known legitimate site',
      ),
      (
        input: 'https://github.com',
        expectMalicious: false,
        description: 'Developer platform',
      ),
      (
        input: 'https://sbi.co.in',
        expectMalicious: false,
        description: 'Official SBI domain',
      ),
      (
        input: 'https://onlinesbi.sbi',
        expectMalicious: false,
        description: 'Official SBI internet banking',
      ),
      (
        input: 'https://hdfcbank.com',
        expectMalicious: false,
        description: 'Official HDFC Bank',
      ),
      (
        input: 'https://paytm.com',
        expectMalicious: false,
        description: 'Official Paytm',
      ),
      (
        input: 'https://incometax.gov.in',
        expectMalicious: false,
        description: 'Official government portal',
      ),
    ];

    test('URL metrics: compute and assert coverage (synthetic)', () async {
      final freshResults = <RiskLevel>[];
      for (final c in cases) {
        final r = await UrlAnalysisService.analyzeUrl(c.input);
        freshResults.add(r.riskLevel);
      }

      final m = _computeMetrics(
        label: 'URL ANALYSIS',
        cases: cases,
        results: freshResults,
      );

      expect(cases.where((c) => c.expectMalicious).length, greaterThan(0));
      expect(cases.where((c) => !c.expectMalicious).length, greaterThan(0));
      expect(m['tp'] as int, greaterThan(0));
      expect(m['tn'] as int, greaterThan(0));

      final fpr = m['fpr'] as double;
      expect(
        fpr,
        lessThan(0.4),
        reason: 'FPR must be < 40% on synthetic URL dataset with documented threshold rationale',
      );
    });

    for (final c in cases) {
      test('${c.expectMalicious ? "Malicious" : "Benign"}: ${c.description}', () async {
        final r = await UrlAnalysisService.analyzeUrl(c.input);
        if (c.expectMalicious) {
          expect(
            r.riskLevel.index,
            greaterThanOrEqualTo(RiskLevel.medium.index),
            reason: '${c.description}: Expected ≥medium. Got: ${r.riskLevel}',
          );
        } else {
          expect(
            r.riskLevel.index,
            lessThanOrEqualTo(RiskLevel.low.index),
            reason:
                '${c.description}: Expected ≤low (no false positive). Got: ${r.riskLevel}',
          );
        }
      });
    }
  });

  // ===========================================================================
  // SMS ANALYSIS — INDIVIDUAL FOCUSED TESTS
  // ===========================================================================
  group('SMS Analysis — Individual Focused Tests (Synthetic)', () {
    test('PAN blocking + urgency + callback number → high', () async {
      final r = await SmsAnalysisService.analyzeSms(
        'URGENT: Your PAN will be BLOCKED. Call 9876543210.',
      );
      expect(
        r.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.high.index),
        reason: 'PAN block threat + urgency + mobile number.',
      );
    });

    test(
      'Explicit OTP share request → high (active credential harvesting)',
      () async {
        final r = await SmsAnalysisService.analyzeSms(
          'Your HDFC Bank OTP is 123456. Share this OTP with our executive.',
        );
        expect(
          r.riskLevel.index,
          greaterThanOrEqualTo(RiskLevel.high.index),
          reason: 'Asking for OTP to be shared is credential harvesting.',
        );
      },
    );

    test(
      '"Do not share" OTP message → medium or below (legitimate OTP warning)',
      () async {
        final r = await SmsAnalysisService.analyzeSms(
          '123456 is your OTP for HDFC Bank. Do not share this with anyone.',
        );
        expect(r.riskLevel, isNot(RiskLevel.critical));
        expect(r.riskLevel, isNot(RiskLevel.high));
      },
    );

    test('Lottery scam with suspicious URL → critical', () async {
      final r = await SmsAnalysisService.analyzeSms(
        'Congratulations! You won 50 lakhs cash in KBC lottery. Claim at https://lottery-fake.top',
      );
      expect(r.riskLevel, RiskLevel.critical);
    });

    test('Legitimate transaction debit alert → safe or low', () async {
      final r = await SmsAnalysisService.analyzeSms(
        'Rs 500 debited from your SBI account ending 1234 on 28-Oct. Balance: Rs 15200.00.',
      );
      expect(r.riskLevel.index, lessThanOrEqualTo(RiskLevel.low.index));
    });
  });

  // ===========================================================================
  // SMS ANALYSIS — FULL SYNTHETIC REGRESSION SUITE + METRICS
  // ===========================================================================
  group('SMS Analysis — Synthetic Regression Suite + Metrics', () {
    final cases = <({String input, bool expectMalicious, String description})>[
      // MALICIOUS
      (
        input: 'URGENT: Your PAN will be BLOCKED. Call 9876543210.',
        expectMalicious: true,
        description: 'KYC threat + urgency + mobile callback',
      ),
      (
        input:
            'Your HDFC Bank OTP is 123456. Share this OTP with our executive.',
        expectMalicious: true,
        description: 'Explicit OTP share request',
      ),
      (
        input: 'Electricity disconnection within 2 hours. Call 9123456789.',
        expectMalicious: true,
        description: 'Utility extortion + urgency + mobile',
      ),
      (
        input: 'Congratulations won 50 lakhs cash in KBC lottery. Claim at https://lottery-fake.top',
        expectMalicious: true,
        description: 'Lottery scam with suspicious URL',
      ),
      (
        input: 'Your debit card has been blocked. Verify KYC at https://sbi-kyc-verify.xyz',
        expectMalicious: true,
        description: 'Card block + KYC + suspicious URL',
      ),
      (
        input: 'Aadhaar update required. Click https://uidai-update.work',
        expectMalicious: true,
        description: 'Aadhaar impersonation + .work TLD',
      ),
      (
        input: 'BESCOM: Your power will be disconnected today. Pay at https://bescom-pay.click',
        expectMalicious: true,
        description: 'Utility brand impersonation + .click TLD',
      ),
      // LEGITIMATE
      (
        input: 'Your Swiggy order #ABC123 has been delivered.',
        expectMalicious: false,
        description: 'Delivery notification',
      ),
      (
        input: 'Meeting rescheduled to 3 PM tomorrow.',
        expectMalicious: false,
        description: 'Personal message',
      ),
      (
        input: 'Your electricity bill for January is Rs 1200. Pay by 15th.',
        expectMalicious: false,
        description: 'Utility bill reminder (no urgency/mobile)',
      ),
      (
        input: 'Rs 500 debited from SBI account ending 1234. Available balance: Rs 15200.',
        expectMalicious: false,
        description: 'Legitimate bank transaction alert',
      ),
    ];

    test('Metrics: compute and assert coverage (synthetic)', () async {
      final freshResults = <RiskLevel>[];
      for (final c in cases) {
        final r = await SmsAnalysisService.analyzeSms(c.input);
        freshResults.add(r.riskLevel);
      }
      final m = _computeMetrics(
        label: 'SMS ANALYSIS',
        cases: cases,
        results: freshResults,
      );
      expect(cases.where((c) => c.expectMalicious).length, greaterThan(0));
      expect(cases.where((c) => !c.expectMalicious).length, greaterThan(0));
      expect(m['tp'] as int, greaterThan(0));
      expect(m['tn'] as int, greaterThan(0));

      final fpr = m['fpr'] as double;
      expect(
        fpr,
        lessThan(0.4),
        reason: 'FPR must be < 40% on synthetic SMS dataset with documented threshold rationale',
      );
    });

    for (final c in cases) {
      test('${c.expectMalicious ? "Malicious" : "Benign"}: ${c.description}', () async {
        final r = await SmsAnalysisService.analyzeSms(c.input);
        if (c.expectMalicious) {
          expect(
            r.riskLevel.index,
            greaterThanOrEqualTo(RiskLevel.medium.index),
            reason: '${c.description}: Expected ≥medium. Got: ${r.riskLevel}',
          );
        } else {
          expect(
            r.riskLevel.index,
            lessThan(RiskLevel.critical.index),
            reason:
                '${c.description}: Legitimate SMS must not be critical. Got: ${r.riskLevel}',
          );
        }
      });
    }
  });

  // ===========================================================================
  // VOICE ANALYSIS — INDIVIDUAL FOCUSED TESTS
  // ===========================================================================
  group('Voice Analysis — Individual Focused Tests (Synthetic)', () {
    final svc = VoiceAnalysisService();

    test('Digital arrest + isolation + remote access → critical', () async {
      final r = await svc.classifyTranscript(
        'You are under digital arrest. Do not disconnect. Download AnyDesk.',
      );
      expect(r.riskLevel, RiskLevel.critical);
    });

    test('CBI impersonation + money transfer demand → critical', () async {
      final r = await svc.classifyTranscript(
        'CBI officer here. Your PAN linked to drug money. Transfer 50,000 to verify account.',
      );
      expect(r.riskLevel, RiskLevel.critical);
    });

    test('Ordinary meeting reschedule → safe', () async {
      final r = await svc.classifyTranscript(
        'Hi, can we reschedule our meeting?',
      );
      expect(r.riskLevel.index, lessThanOrEqualTo(RiskLevel.low.index));
    });
  });

  // ===========================================================================
  // VOICE ANALYSIS — FULL SYNTHETIC REGRESSION SUITE + METRICS
  // ===========================================================================
  group('Voice Analysis — Synthetic Regression Suite + Metrics', () {
    final svc = VoiceAnalysisService();

    final cases = <({String input, bool expectMalicious, String description})>[
      // MALICIOUS
      (
        input: 'You are under digital arrest. Do not disconnect. Download AnyDesk.',
        expectMalicious: true,
        description: 'Digital arrest + isolation + remote access',
      ),
      (
        input: 'CBI officer here. Your PAN linked to drug money. Transfer 50,000 to verify account.',
        expectMalicious: true,
        description: 'CBI impersonation + money transfer demand',
      ),
      (
        input: 'This is SBI manager. Your card expired. Tell me CVV and OTP.',
        expectMalicious: true,
        description: 'Bank impersonation + credential request',
      ),
      (
        input: 'Customs found illegal parcel. Pay 20,000 security deposit. Do not tell family.',
        expectMalicious: true,
        description: 'Customs scam + secrecy + money demand',
      ),
      (
        input: 'Stay on the call. Go to a quiet room. Install TeamViewer now.',
        expectMalicious: true,
        description: 'Isolation + remote access installation',
      ),
      // LEGITIMATE
      (
        input: 'Hi, can we reschedule our meeting?',
        expectMalicious: false,
        description: 'Ordinary personal conversation',
      ),
      (
        input: 'Your delivery will arrive between 2-4 PM.',
        expectMalicious: false,
        description: 'Delivery notification',
      ),
      (
        input: 'This is HDFC Bank calling about a loan offer. Press 1 for details.',
        expectMalicious: false,
        description: 'Legitimate bank marketing IVR',
      ),
      (
        input: 'The doctor will see you now.',
        expectMalicious: false,
        description: 'Healthcare appointment',
      ),
    ];

    test('Metrics: compute and assert coverage (synthetic)', () async {
      final freshResults = <RiskLevel>[];
      for (final c in cases) {
        final r = await svc.classifyTranscript(c.input);
        freshResults.add(r.riskLevel);
      }
      final m = _computeMetrics(
        label: 'VOICE ANALYSIS',
        cases: cases,
        results: freshResults,
      );
      expect(cases.where((c) => c.expectMalicious).length, greaterThan(0));
      expect(cases.where((c) => !c.expectMalicious).length, greaterThan(0));
      expect(m['tp'] as int, greaterThan(0));
      expect(m['tn'] as int, greaterThan(0));

      final fpr = m['fpr'] as double;
      expect(
        fpr,
        lessThan(0.4),
        reason: 'FPR must be < 40% on synthetic voice dataset with documented threshold rationale',
      );
    });

    for (final c in cases) {
      test('${c.expectMalicious ? "Malicious" : "Benign"}: ${c.description}', () async {
        final r = await svc.classifyTranscript(c.input);
        if (c.expectMalicious) {
          expect(
            r.riskLevel.index,
            greaterThanOrEqualTo(RiskLevel.medium.index),
            reason: '${c.description}: Expected ≥medium. Got: ${r.riskLevel}',
          );
        } else {
          expect(
            r.riskLevel.index,
            lessThanOrEqualTo(RiskLevel.low.index),
            reason:
                '${c.description}: Legitimate call must be ≤low. Got: ${r.riskLevel}',
          );
        }
      });
    }
  });
}
