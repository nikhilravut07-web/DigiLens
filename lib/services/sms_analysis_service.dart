import 'package:digilens/models/scan_result.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

/// Production-grade SMS fraud (smishing) analysis service.
///
/// Inspects message text for social engineering patterns: urgency, OTP requests,
/// fake KYC, account blocking threats, utility extortion, advance-fee lotteries,
/// and embedded malicious URLs.
class SmsAnalysisService {
  static final math.Random _random = math.Random();

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (i) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Analyze SMS text for fraud indicators and return a structured [ScanResult].
  static Future<ScanResult> analyzeSms(String rawSms, {String? sender}) async {
    // Brief simulated delay
    await Future.delayed(const Duration(milliseconds: 600));

    final trimmed = rawSms.trim();
    if (trimmed.isEmpty) {
      return _emptyResult(rawSms);
    }

    final lower = trimmed.toLowerCase();
    int riskScore = 0;
    final warnings = <WarningIndicator>[];
    String? claimedBrand;

    // Extract any URLs present in the message
    final extractedUrls = _extractUrls(trimmed);

    // ── 1. Manufactured Urgency ───────────────────────────────────────────
    const urgencyKeywords = [
      'urgent',
      'immediately',
      'within 24 hours',
      'act now',
      'expires today',
      'last warning',
      'final notice',
      'suspended tonight',
      'blocked today',
      'within 2 hours',
      'immediately block',
    ];
    if (urgencyKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 20;
      warnings.add(
        const WarningIndicator(
          title: 'Manufactured urgency',
          description:
              'Scammers create false deadlines (e.g. "within 24 hours") to induce '
              'panic and prevent victims from verifying claims.',
          icon: Icons.schedule,
        ),
      );
    }

    // ── 2. OTP / Verification Code requests ────────────────────────────────
    const otpKeywords = [
      'otp',
      'one time password',
      'verification code',
      'pin',
      'share otp',
      'tell otp',
      'send otp',
      'give otp',
      'provide otp',
      'cvv',
      'card number',
      'atm pin',
    ];
    final hasOtpKeyword = otpKeywords.any((kw) => lower.contains(kw));
    if (hasOtpKeyword) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'OTP / PIN request',
          description:
              'Legitimate banks, government bodies, and service providers NEVER '
              'ask for your One-Time Password (OTP) via SMS, call, or message.',
          icon: Icons.pin,
        ),
      );
    }

    // Additional penalty: if message explicitly requests sharing/sending credentials
    // Must NOT match "do not share" or "don't share" (legitimate OTP messages)
    final asksForCredential =
        hasOtpKeyword &&
        (lower.contains('share this') ||
            lower.contains('share your') ||
            lower.contains('share otp') ||
            lower.contains('tell otp') ||
            lower.contains('send otp') ||
            lower.contains('provide otp') ||
            lower.contains('give otp') ||
            lower.contains('share the otp') ||
            lower.contains('tell me') ||
            lower.contains('tell us')) &&
        !lower.contains('do not share') &&
        !lower.contains("don't share") &&
        !lower.contains('never share');
    if (asksForCredential) {
      riskScore += 25; // Active credential harvesting attempt
    }

    // ── 3. Account block / KYC threat ─────────────────────────────────────
    final kycMatches = [
      'kyc',
      'pan',
      'aadhaar',
      'account blocked',
      'account suspended',
      'debit card blocked',
      'atm blocked',
      'bank account closed',
      'verify kyc',
      'blocked',
      'suspended',
      'freeze',
      'frozen',
    ].where((kw) => lower.contains(kw)).toList();

    if (kycMatches.isNotEmpty) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Fake KYC / Account suspension threat',
          description:
              'A common Indian phishing tactic: claiming your bank account or '
              'PAN/Aadhaar will be blocked unless you click a link or call.',
          icon: Icons.account_balance,
        ),
      );
    }

    // ── 4. Utility extortion (Electricity, Gas, Fastag) ────────────────────
    const utilityKeywords = [
      'electricity',
      'power disconnected',
      'disconnection',
      'bill unpaid',
      'fastag',
      'gas connection',
      'bescom',
      'tata power',
      'adani power',
      'mseb',
      'cesc',
    ];
    if (utilityKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 25;
      warnings.add(
        const WarningIndicator(
          title: 'Utility disconnection threat',
          description:
              'Fraudsters send fake power or utility disconnection notices with '
              'a mobile number to trick you into calling and installing remote-access apps.',
          icon: Icons.bolt,
        ),
      );
    }

    // ── 5. Advance-fee lottery / prize scam ──────────────────────────────
    const lotteryKeywords = [
      'congratulations won',
      'lottery',
      'lucky draw',
      'prize',
      'crore',
      'lakhs cash',
      'kbc winner',
      'kaun banega crorepati',
    ];
    final hasLottery = lotteryKeywords.any((kw) => lower.contains(kw));
    if (hasLottery) {
      riskScore += 45; // Lottery scams are nearly 100% fraudulent
      warnings.add(
        const WarningIndicator(
          title: 'Advance-fee prize scam',
          description:
              'Promises of unearned lotteries or cash prizes require an "advance fee" '
              'or processing tax payment before funds are released. This is always a scam.',
          icon: Icons.card_giftcard,
        ),
      );
    }

    // Additional penalty: lottery + URL is a classic smishing attack
    if (hasLottery && extractedUrls.isNotEmpty) {
      riskScore += 20; // Lottery with suspicious link = likely phishing
    }

    // ── 6. Embedded suspicious URLs ────────────────────────────────────────
    if (extractedUrls.isNotEmpty) {
      riskScore += 25;
      warnings.add(
        WarningIndicator(
          title: 'Contains ${extractedUrls.length} web link(s)',
          description:
              'Message contains external links: ${extractedUrls.first}. '
              'Links in SMS from unknown senders frequently lead to credential-harvesting sites.',
          icon: Icons.link,
        ),
      );
    }

    // ── 7. Personal mobile numbers acting as helplines ────────────────────
    // Official boards use shortcodes (e.g. 1930, 1900) or official toll-free numbers.
    final tenDigitPhonePattern = RegExp(r'\b[6-9]\d{9}\b');
    if (tenDigitPhonePattern.hasMatch(trimmed) &&
        (utilityKeywords.any((kw) => lower.contains(kw)) ||
            kycMatches.isNotEmpty)) {
      riskScore += 25;
      warnings.add(
        const WarningIndicator(
          title: 'Personal mobile number as official helpline',
          description:
              'Official utilities and banks never provide a standard 10-digit mobile '
              'number (starting with 6-9) as their emergency customer care helpline.',
          icon: Icons.phone_android,
        ),
      );
    }

    // ── 8. Claimed brand detection ─────────────────────────────────────────
    const brandMap = {
      'sbi': 'State Bank of India',
      'hdfc': 'HDFC Bank',
      'icici': 'ICICI Bank',
      'axis': 'Axis Bank',
      'paytm': 'Paytm',
      'phonepe': 'PhonePe',
      'incometax': 'Income Tax Department',
      'electricity': 'State Electricity Board',
    };
    for (final entry in brandMap.entries) {
      if (lower.contains(entry.key)) {
        claimedBrand = entry.value;
        break;
      }
    }

    // ── Calculate risk level ───────────────────────────────────────────────
    final riskLevel = _calculateRiskLevel(riskScore);

    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.sms,
      riskLevel: riskLevel,
      riskScore: riskScore,
      title: _titleForRisk(riskLevel),
      description: _descriptionForRisk(riskLevel, warnings.length),
      warnings: warnings,
      recommendation: _smsRecommendation(riskLevel),
      claimedBrand: claimedBrand,
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: rawSms,
      extractedUrls: extractedUrls,
      sender: sender,
    );
  }

  // ─── URL extraction helper ────────────────────────────────────────────────
  static List<String> _extractUrls(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    );
    return urlRegex.allMatches(text).map((m) => m.group(0) ?? '').toList();
  }

  static RiskLevel _calculateRiskLevel(int score) {
    if (score >= 75) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 30) return RiskLevel.medium;
    if (score >= 15) return RiskLevel.low;
    return RiskLevel.safe;
  }

  static String _titleForRisk(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No Obvious Fraud Indicators';
      case RiskLevel.low:
        return 'Low Risk Message';
      case RiskLevel.medium:
        return 'Caution Advised — Suspicious Wording';
      case RiskLevel.high:
        return 'Suspicious SMS — Likely Smishing';
      case RiskLevel.critical:
        return 'High Risk Scam SMS — Avoid';
    }
  }

  static String _descriptionForRisk(RiskLevel level, int warningCount) {
    if (level == RiskLevel.safe) {
      return 'The message text did not trigger common SMS scam patterns. '
          'However, always verify unexpected messages with official sources.';
    }
    return 'Analysis detected $warningCount warning indicator(s) commonly '
        'found in SMS phishing (smishing) and financial fraud attempts.';
  }

  static String _smsRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'Always verify unexpected messages with official customer care '
            'numbers found on official cards or websites.';
      case RiskLevel.low:
        return 'Exercise caution. Do not click links or call numbers provided '
            'in the message without independent verification.';
      case RiskLevel.medium:
        return 'Do not reply, click links, or call the provided number. '
            'Check your account status directly inside your official banking app.';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'Do NOT click links, call numbers, or share any OTP or personal '
            'information. Report this SMS as spam/fraud to TRAI or Chakshu portal '
            '(sancharsaathi.gov.in) and call 1930 if financial fraud occurred.';
    }
  }

  static ScanResult _emptyResult(String rawInput) {
    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.sms,
      riskLevel: RiskLevel.safe,
      riskScore: 0,
      title: 'Empty Message',
      description: 'The provided message text was empty.',
      warnings: const [],
      recommendation: 'Enter a valid SMS message to analyze.',
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: rawInput,
    );
  }
}
