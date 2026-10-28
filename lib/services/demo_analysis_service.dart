import 'package:digilens/models/scan_result.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

/// Mock analysis service for demo purposes.
/// NOTE: This is a simulated service that does NOT connect to real threat intelligence.
/// In production, replace this with actual API calls to a threat detection backend.
class DemoAnalysisService {
  static final math.Random _random = math.Random();

  /// Generates a unique ID for scan results.
  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (i) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Analyzes a URL for potential threats.
  /// Returns a mock result that clearly labels itself as simulated.
  static Future<ScanResult> analyzeUrl(String url) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final hasSuspiciousTld = _hasSuspiciousTld(url);
    final hasIpAddress = _hasIpAddress(url);
    final hasSuspiciousKeywords = _hasSuspiciousKeywords(url);
    final hasShortenedDomain = _isShortenedUrl(url);
    final hasTyposquatting = _checkTyposquatting(url);

    int riskScore = 0;
    List<WarningIndicator> warnings = [];

    if (hasSuspiciousTld) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Unusual domain extension',
          description: 'This URL uses a less common top-level domain often associated with phishing.',
          icon: Icons.dns,
        ),
      );
    }

    if (hasIpAddress) {
      riskScore += 40;
      warnings.add(
        const WarningIndicator(
          title: 'IP address instead of domain',
          description:
              'Legitimate websites rarely use raw IP addresses in URLs.',
          icon: Icons.wifi,
        ),
      );
    }

    if (hasSuspiciousKeywords) {
      riskScore += 25;
      warnings.add(
        const WarningIndicator(
          title: 'Suspicious keywords',
          description: 'URL contains terms commonly used in phishing attempts.',
          icon: Icons.warning_amber,
        ),
      );
    }

    if (hasShortenedDomain) {
      riskScore += 20;
      warnings.add(
        const WarningIndicator(
          title: 'URL shortener detected',
          description: 'Shortened URLs can hide malicious destinations.',
          icon: Icons.link_off,
        ),
      );
    }

    if (hasTyposquatting) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Possible typosquatting',
          description: 'This domain resembles a well-known brand but with slight variations.',
          icon: Icons.domain,
        ),
      );
    }

    // Determine risk level based on score
    final riskLevel = _calculateRiskLevel(riskScore);

    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.link,
      riskLevel: riskLevel,
      title: _getTitle(riskLevel),
      description: _getUrlDescription(riskLevel, warnings.length),
      warnings: warnings,
      recommendation: _getRecommendation(riskLevel),
    );
  }

  /// Analyzes SMS content for potential threats.
  /// Returns a mock result based on heuristic patterns.
  static Future<ScanResult> analyzeSms(String message) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final messageLower = message.toLowerCase();
    List<WarningIndicator> warnings = [];
    int riskScore = 0;

    // Check for urgency
    if (messageLower.contains('urgent') ||
        messageLower.contains('immediately') ||
        messageLower.contains('within 24 hours') ||
        messageLower.contains('act now')) {
      riskScore += 20;
      warnings.add(
        const WarningIndicator(
          title: 'Creates urgency',
          description:
              'Scammers often use urgent language to pressure victims.',
          icon: Icons.schedule,
        ),
      );
    }

    // Check for OTP requests
    if (messageLower.contains('otp') ||
        messageLower.contains('one time password') ||
        messageLower.contains('verification code')) {
      riskScore += 25;
      warnings.add(
        const WarningIndicator(
          title: 'OTP request',
          description: 'Legitimate services never ask for OTP via SMS.',
          icon: Icons.pin,
        ),
      );
    }

    // Check for payment demands
    if (messageLower.contains('bank account') ||
        messageLower.contains('update payment') ||
        messageLower.contains('credit card') ||
        messageLower.contains('debit card')) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Payment information request',
          description: 'Banks never ask for card details via SMS.',
          icon: Icons.credit_card,
        ),
      );
    }

    // Check for suspicious links
    if (_containsSuspiciousLink(message)) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Suspicious link',
          description:
              'Message contains links that may lead to phishing sites.',
          icon: Icons.link,
        ),
      );
    }

    // Check for impersonation
    if (_isImpersonationAttempt(messageLower)) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Possible impersonation',
          description: 'Message claims to be from a known organization.',
          icon: Icons.person_off,
        ),
      );
    }

    // Check for credential requests
    if (messageLower.contains('password') ||
        messageLower.contains('login') ||
        messageLower.contains('account details')) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Credential request',
          description: 'Legitimate services never ask for passwords via SMS.',
          icon: Icons.key,
        ),
      );
    }

    // Check for UPI/financial keywords
    if (messageLower.contains('upi') ||
        messageLower.contains('wallet') ||
        messageLower.contains('kYC') ||
        messageLower.contains('kyc')) {
      riskScore += 20;
      warnings.add(
        const WarningIndicator(
          title: 'Financial transaction request',
          description: 'Be cautious of messages about financial transactions.',
          icon: Icons.account_balance_wallet,
        ),
      );
    }

    // Determine risk level
    final riskLevel = _calculateRiskLevel(riskScore);

    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.sms,
      riskLevel: riskLevel,
      title: _getSmsTitle(riskLevel),
      description: _getSmsDescription(riskLevel, warnings.length),
      warnings: warnings,
      recommendation: _getSmsRecommendation(riskLevel),
    );
  }

  /// Returns a placeholder for voice analysis (not yet implemented).
  static Future<ScanResult> createVoicePlaceholder() async {
    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.voice,
      riskLevel: RiskLevel.low,
      title: 'Voice Threat Analysis Coming Soon',
      description: 'This feature will allow you to analyze potential voice-based social engineering attempts. Upload or record a call to detect common scam patterns.',
      warnings: const [],
      recommendation: 'Voice threat analysis is under development. For now, remain vigilant of unexpected calls claiming to be from banks, government agencies, or tech support.',
    );
  }

  // Helper methods
  static bool _hasSuspiciousTld(String url) {
    final suspiciousTlds = [
      '.xyz',
      '.top',
      '.click',
      '.work',
      '.download',
      '.stream',
      '.loan',
      '.men',
      '.win',
      '.zip',
      '.mov',
      '.tk',
      '.ml',
      '.ga',
      '.cf',
      '.gq',
      '.cc',
    ];
    return suspiciousTlds.any((tld) => url.toLowerCase().endsWith(tld));
  }

  static bool _hasIpAddress(String url) {
    final ipPattern = r'http[s]?://(\d{1,3}\.){3}\d{1,3}';
    return RegExp(ipPattern).hasMatch(url);
  }

  static bool _hasSuspiciousKeywords(String url) {
    final keywords = [
      'login',
      'signin',
      'verify',
      'secure',
      'update',
      'confirm',
      'account',
      'bank',
      'paypal',
      'apple',
      'google',
      'microsoft',
      'amazon',
    ];
    return keywords.any((kw) => url.toLowerCase().contains(kw));
  }

  static bool _isShortenedUrl(String url) {
    final shorteners = [
      'bit.ly',
      'tinyurl.com',
      't.co',
      'goo.gl',
      'ow.ly',
      'is.gd',
      'buff.ly',
    ];
    return shorteners.any((s) => url.toLowerCase().contains(s));
  }

  static bool _checkTyposquatting(String url) {
    // Simple heuristic for demo - check for common typosquatting patterns
    final typosquatPatterns = [
      'amaz0n',
      'g00gle',
      'micr0soft',
      'paypa1',
      'faceb00k',
      'app1e',
      'amazOn',
      'gOogle',
      'mIcrosOft',
    ];
    return typosquatPatterns.any(
      (p) => url.toLowerCase().contains(p.toLowerCase()),
    );
  }

  static bool _containsSuspiciousLink(String message) {
    // Look for links with suspicious patterns
    final linkPattern = RegExp(r'https?://[^\s]+');
    final links = linkPattern.allMatches(message);

    for (final link in links) {
      final url = link.group(0) ?? '';
      if (_hasSuspiciousTld(url) || _isShortenedUrl(url)) {
        return true;
      }
    }
    return false;
  }

  static bool _isImpersonationAttempt(String message) {
    final impersonationPatterns = [
      'your bank',
      'sbi',
      'hdfc',
      'icici',
      'axis bank',
      'income tax',
      'aadhar',
      'pan card',
      'gov.in',
      'amazon customer service',
      'paytm',
      'phonepe',
    ];
    return impersonationPatterns.any((p) => message.contains(p));
  }

  static RiskLevel _calculateRiskLevel(int score) {
    if (score >= 80) return RiskLevel.critical;
    if (score >= 60) return RiskLevel.high;
    if (score >= 40) return RiskLevel.medium;
    if (score >= 20) return RiskLevel.low;
    return RiskLevel.safe;
  }

  static String _getTitle(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No Obvious Threats Detected';
      case RiskLevel.low:
        return 'Low Risk URL';
      case RiskLevel.medium:
        return 'Caution Advised';
      case RiskLevel.high:
        return 'Suspicious URL Detected';
      case RiskLevel.critical:
        return 'High Risk URL - Avoid';
    }
  }

  static String _getUrlDescription(RiskLevel level, int warningCount) {
    if (level == RiskLevel.safe) {
      return 'The URL passed basic validation checks. However, this is a simulated analysis and does not guarantee safety. Always exercise caution when visiting unfamiliar websites.';
    }
    return 'Analysis detected $warningCount warning indicators. This URL exhibits characteristics commonly associated with phishing or malicious sites. Proceed with extreme caution.';
  }

  static String _getSmsTitle(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No Obvious Red Flags';
      case RiskLevel.low:
        return 'Low Risk Message';
      case RiskLevel.medium:
        return 'Caution Advised';
      case RiskLevel.high:
        return 'Suspicious Message';
      case RiskLevel.critical:
        return 'High Risk - Likely Scam';
    }
  }

  static String _getSmsDescription(RiskLevel level, int warningCount) {
    if (level == RiskLevel.safe) {
      return 'The message did not trigger common scam patterns. However, always verify with the official source before taking any action.';
    }
    return 'Analysis detected $warningCount warning indicators commonly found in SMS phishing attempts. Be cautious of requests for sensitive information.';
  }

  static String _getRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'While no obvious threats were detected, always verify URLs manually before entering personal information. Bookmark trusted sites for future use.';
      case RiskLevel.low:
        return 'Exercise normal caution. If you must visit this site, avoid entering personal or financial information.';
      case RiskLevel.medium:
        return 'We recommend avoiding this URL. If you need to visit it, use a secure browser with anti-phishing protection and never enter sensitive information.';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'Do not visit this URL. If you have already entered information, monitor your accounts for suspicious activity. Consider running a security scan on your device.';
    }
  }

  static String _getSmsRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'Always verify unexpected messages with official sources using official contact numbers from their website or cards.';
      case RiskLevel.low:
        return 'Verify the sender through official channels before responding or clicking any links.';
      case RiskLevel.medium:
        return 'Do not click links or share personal information. Contact the alleged sender using official contact methods.';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'Do not respond or share any information. Report this SMS to your bank and TRAI (1900). Delete the message immediately.';
    }
  }
}
