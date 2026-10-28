import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';

/// Production-grade URL analysis service using local heuristic rules.
///
/// This service does NOT connect to any external threat-intelligence API.
/// All analysis is performed on-device using pattern matching and known-bad
/// indicators. Results are labelled as [AnalysisMethod.localHeuristics].
///
/// To add live reputation checking, implement a backend proxy and call it
/// from [_checkThreatIntelligence] — never embed API keys in client code.
class UrlAnalysisService {
  static final math.Random _random = math.Random();

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (i) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Analyse a URL and return a structured [ScanResult].
  ///
  /// The URL is normalized before analysis. If parsing fails completely,
  /// the result describes the parsing error rather than inventing a verdict.
  static Future<ScanResult> analyzeUrl(String rawUrl) async {
    // Brief pause to avoid UI flash (analysis is synchronous but future-based
    // for API compatibility).
    await Future.delayed(const Duration(milliseconds: 600));

    final trimmed = rawUrl.trim();
    final lowerTrimmed = trimmed.toLowerCase();

    // ── Pre-check: Non-HTTP executable schemes (javascript: / data:) ─────────
    // These must never be passed to a browser for execution.
    if (lowerTrimmed.startsWith('javascript:') ||
        lowerTrimmed.startsWith('data:')) {
      return ScanResult(
        id: _generateId(),
        timestamp: DateTime.now(),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        riskScore: 90,
        title: 'Dangerous Non-HTTP URI Scheme',
        description:
            'The input uses a dangerous scheme (javascript: or data:) that can '
            'execute arbitrary code or present misleading content. It must never '
            'be passed to a browser for execution.',
        warnings: const [
          WarningIndicator(
            title: 'Executable non-HTTP scheme detected',
            description:
                'data: and javascript: URIs are not web addresses. They can execute '
                'scripts or render deceptive phishing payloads directly in the browser.',
            icon: Icons.code_off,
          ),
        ],
        recommendation: 'Do NOT open or execute this URI. Delete or discard the link immediately.',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: rawUrl,
      );
    }

    final normalized = _normalize(rawUrl);
    if (normalized == null) {
      return _parsingError(rawUrl);
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return _parsingError(rawUrl);
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final fullUrl = normalized.toLowerCase();

    int riskScore = 0;
    final warnings = <WarningIndicator>[];
    String? claimedBrand;

    // ── 1. IP-address URL ──────────────────────────────────────────────────
    if (_isIpAddress(host)) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'IP address instead of domain name',
          description:
              'Legitimate websites almost always use a registered domain name. '
              'Raw IP addresses are commonly used by attackers to evade domain-based blocklists.',
          icon: Icons.dns_outlined,
        ),
      );
    }

    // ── 2. Suspicious TLD ──────────────────────────────────────────────────
    final tldResult = _checkSuspiciousTld(host);
    if (tldResult != null) {
      riskScore += tldResult.score;
      warnings.add(tldResult.warning);
    }

    // ── 3. URL shortener ───────────────────────────────────────────────────
    if (_isUrlShortener(host)) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'URL shortener detected',
          description:
              'Shortened URLs hide the real destination. Attackers use them to '
              'bypass link previews and human inspection.',
          icon: Icons.link_off,
        ),
      );
    }

    // ── 4. Typosquatting / brand impersonation ─────────────────────────────
    final brandResult = _checkBrandImpersonation(host);
    if (brandResult != null) {
      riskScore += brandResult.score;
      warnings.add(brandResult.warning);
      claimedBrand = brandResult.brand;
    }

    // ── 5. Suspicious subdomain depth ──────────────────────────────────────
    final subdomainResult = _checkSubdomainAbuse(host);
    if (subdomainResult != null) {
      riskScore += subdomainResult.score;
      warnings.add(subdomainResult.warning);
    }

    // ── 6. Sensitive-action keywords in path ───────────────────────────────
    final pathResult = _checkSuspiciousPath(path);
    if (pathResult != null) {
      riskScore += pathResult.score;
      warnings.add(pathResult.warning);
    }

    // ── 7. HTTPS absence ───────────────────────────────────────────────────
    if (uri.scheme == 'http') {
      riskScore += 10;
      warnings.add(
        const WarningIndicator(
          title: 'No HTTPS encryption',
          description:
              'This URL uses unencrypted HTTP. Data you enter (passwords, card numbers) '
              'can be intercepted by anyone on the same network. This alone does not prove '
              'the site is malicious, but legitimate sites handling sensitive data use HTTPS.',
          icon: Icons.lock_open,
        ),
      );
    }

    // ── 8. Homoglyph / punycode ────────────────────────────────────────────
    if (_hasPunycodeOrHomoglyphs(host)) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Internationalized domain (punycode)',
          description:
              'This domain uses characters that look like Latin letters but are from a '
              'different script. Attackers exploit this to create visually identical lookalike domains.',
          icon: Icons.translate,
        ),
      );
    }

    // ── 9. Excessive URL length ────────────────────────────────────────────
    if (fullUrl.length > 200) {
      riskScore += 10;
      warnings.add(
        const WarningIndicator(
          title: 'Unusually long URL',
          description:
              'Attackers sometimes use very long URLs to hide the real path or embed '
              'obfuscated payloads. This is a weak signal on its own.',
          icon: Icons.straighten,
        ),
      );
    }

    // ── 10. @ in URL (credential-prefix trick) ─────────────────────────────
    if (fullUrl.contains('@') && !fullUrl.startsWith('mailto:')) {
      riskScore += 80;
      warnings.add(
        const WarningIndicator(
          title: 'Credential prefix in URL',
          description:
              'The "@" symbol in a URL can trick browsers and humans into thinking the '
              'visible text before it is the real domain, when in fact the domain comes after.',
          icon: Icons.alternate_email,
        ),
      );
    }

    // ── Clamp and decide ───────────────────────────────────────────────────
    final riskLevel = _calculateRiskLevel(riskScore);

    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.link,
      riskLevel: riskLevel,
      riskScore: riskScore,
      title: _titleForRisk(riskLevel),
      description: _descriptionForRisk(riskLevel, warnings.length),
      warnings: warnings,
      recommendation: _urlRecommendation(riskLevel),
      claimedBrand: claimedBrand,
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: rawUrl,
    );
  }

  // ─── Normalization ─────────────────────────────────────────────────────────

  /// Attempts to safely normalize a user-entered URL.
  /// Returns null if the input cannot be salvaged into a valid URL.
  static String? _normalize(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Strip surrounding quotes or angle brackets.
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
        (trimmed.startsWith('<') && trimmed.endsWith('>'))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }

    // javascript: and data: are kept as-is for flagging but are not "URLs".
    if (trimmed.toLowerCase().startsWith('javascript:') ||
        trimmed.toLowerCase().startsWith('data:')) {
      return trimmed;
    }

    // Prepend scheme if missing.
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;

    return trimmed;
  }

  // ─── IP address detection ──────────────────────────────────────────────────

  static bool _isIpAddress(String host) {
    // IPv4
    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host)) return true;
    // IPv6 (simplified check — bracket notation is already stripped by Uri)
    if (host.contains(':') && RegExp(r'^[0-9a-f:]+$').hasMatch(host)) {
      return true;
    }
    return false;
  }

  // ─── TLD analysis ──────────────────────────────────────────────────────────

  static _ScoredWarning? _checkSuspiciousTld(String host) {
    // High-risk: domains frequently abused and almost never used by legitimate
    // organisations. Weighted higher.
    const highRisk = {
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
      '.buzz',
      '.icu',
      '.monster',
      '.surf',
      '.rest',
      '.fit',
    };
    // Moderate: less suspicious but still uncommon for banks/government.
    const moderate = {
      '.info',
      '.biz',
      '.space',
      '.site',
      '.online',
      '.club',
      '.live',
      '.store',
      '.fun',
      '.host',
      '.website',
      '.pw',
    };

    for (final tld in highRisk) {
      if (host.endsWith(tld)) {
        return _ScoredWarning(
          score: 25,
          warning: WarningIndicator(
            title: 'High-risk domain extension ($tld)',
            description:
                'The $tld top-level domain is disproportionately used by phishing '
                'and disposable attack infrastructure.',
            icon: Icons.public_off,
          ),
        );
      }
    }
    for (final tld in moderate) {
      if (host.endsWith(tld)) {
        return _ScoredWarning(
          score: 12,
          warning: WarningIndicator(
            title: 'Uncommon domain extension ($tld)',
            description:
                'While not inherently malicious, $tld domains are less commonly '
                'used by established organisations.',
            icon: Icons.public,
          ),
        );
      }
    }
    return null;
  }

  // ─── URL shortener detection ───────────────────────────────────────────────

  static const _shortenerDomains = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'is.gd',
    'buff.ly',
    'rebrand.ly',
    'shorturl.at',
    'cutt.ly',
    'rb.gy',
    'surl.li',
    'tiny.cc',
    'v.gd',
    'qr.ae',
    'lnkd.in',
  };

  static bool _isUrlShortener(String host) {
    return _shortenerDomains.contains(host);
  }

  // ─── Brand impersonation / typosquatting ───────────────────────────────────

  /// Map of brand keyword → official domains.
  /// If the host contains the keyword but is NOT the official domain,
  /// it is a likely impersonation attempt.
  static const _brandSignatures = <String, List<String>>{
    'sbi': [
      'sbi.co.in',
      'onlinesbi.sbi',
      'onlinesbi.com',
      'sbicap.com',
      'sbicard.com',
    ],
    'hdfc': ['hdfcbank.com', 'hdfcsec.com', 'hdfcfund.com'],
    'icici': ['icicibank.com', 'icicidirect.com', 'icicibank.co.in'],
    'axis': ['axisbank.com', 'axisdirect.in'],
    'paytm': ['paytm.com', 'paytmbank.com'],
    'phonepe': ['phonepe.com'],
    'gpay': ['pay.google.com'],
    'paypal': ['paypal.com', 'paypal.me'],
    'amazon': ['amazon.in', 'amazon.com', 'amazonpay.in'],
    'flipkart': ['flipkart.com'],
    'apple': ['apple.com', 'icloud.com'],
    'google': ['google.com', 'google.co.in', 'googleapis.com'],
    'microsoft': ['microsoft.com', 'live.com', 'outlook.com', 'office.com'],
    'facebook': ['facebook.com', 'fb.com', 'fb.me'],
    'instagram': ['instagram.com'],
    'whatsapp': ['whatsapp.com'],
    'incometax': ['incometax.gov.in', 'incometaxindia.gov.in'],
    'aadhaar': ['uidai.gov.in'],
    'epfo': ['epfindia.gov.in'],
  };

  static _BrandWarning? _checkBrandImpersonation(String host) {
    // Normalize homoglyphs for checking
    final normalizedHost = host
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('rn', 'm')
        .replaceAll('vv', 'w')
        .replaceAll('cl', 'd');

    for (final entry in _brandSignatures.entries) {
      final keyword = entry.key;
      final officialDomains = entry.value;

      // Host mentions the brand directly or via homoglyphs?
      final mentionsDirectly = host.contains(keyword);
      final mentionsNormalized = normalizedHost.contains(keyword);

      if (!mentionsDirectly && !mentionsNormalized) {
        continue;
      }

      // If it mentions directly or normalized, check if it's an official domain
      if (officialDomains.any((d) => host == d || host.endsWith('.$d'))) {
        continue; // Legitimate official domain
      }

      // If it matched via homoglyph normalization rather than direct mention
      if (!mentionsDirectly && mentionsNormalized) {
        return _BrandWarning(
          score: 55,
          brand: keyword,
          warning: WarningIndicator(
            title: 'Lookalike domain (possible typosquatting)',
            description:
                'This domain uses character substitutions that make it '
                'visually resemble "$keyword" branding.',
            icon: Icons.text_rotation_none,
          ),
        );
      }

      final isGovBrand =
          keyword == 'incometax' || keyword == 'aadhaar' || keyword == 'epfo';
      return _BrandWarning(
        score: isGovBrand ? 55 : 35,
        brand: keyword,
        warning: WarningIndicator(
          title: 'Possible brand impersonation ($keyword)',
          description:
              'The domain mentions "$keyword" but is not the official '
              '${officialDomains.first} domain. This is a common phishing technique.',
          icon: Icons.domain_verification_outlined,
        ),
      );
    }
    return null;
  }

  // ─── Subdomain abuse ───────────────────────────────────────────────────────

  static _ScoredWarning? _checkSubdomainAbuse(String host) {
    final parts = host.split('.');
    // e.g. "secure.login.bankname.phishing.xyz" has 5 parts.
    if (parts.length >= 5) {
      return _ScoredWarning(
        score: 20,
        warning: const WarningIndicator(
          title: 'Excessive subdomain depth',
          description:
              'Multiple nested subdomains are unusual for legitimate websites and '
              'are commonly used to make URLs appear trustworthy at first glance.',
          icon: Icons.layers_outlined,
        ),
      );
    }

    // Common two-level TLDs
    const twoLevelTlds = {
      'co.in',
      'gov.in',
      'org.in',
      'ac.in',
      'net.in',
      'co.uk',
      'org.uk',
      'gov.uk',
      'com.au',
      'net.au',
    };

    final isTwoLevelTld = twoLevelTlds.any((tld) => host.endsWith('.$tld'));
    final requiredPartsForSubdomain = isTwoLevelTld ? 4 : 3;

    // Attackers put brand names as subdomains: "sbi.login.evil.xyz"
    if (parts.length >= requiredPartsForSubdomain) {
      final tldParts = isTwoLevelTld ? 2 : 1;
      final subdomain = parts.sublist(0, parts.length - 1 - tldParts).join('.');
      for (final entry in _brandSignatures.entries) {
        final brand = entry.key;
        final officialDomains = entry.value;

        // Skip if this host is already recognized as an official domain for this brand
        if (officialDomains.any((d) => host == d || host.endsWith('.$d'))) {
          continue;
        }

        if (subdomain.contains(brand)) {
          return _ScoredWarning(
            score: 25,
            warning: WarningIndicator(
              title: 'Brand name in subdomain',
              description:
                  'The subdomain "$subdomain" contains "$brand" to mimic '
                  'a trusted organisation, but the actual domain is different.',
              icon: Icons.subdirectory_arrow_right,
            ),
          );
        }
      }
    }
    return null;
  }

  // ─── Path analysis ─────────────────────────────────────────────────────────

  static _ScoredWarning? _checkSuspiciousPath(String path) {
    const sensitivePatterns = [
      'login',
      'signin',
      'sign-in',
      'verify',
      'secure',
      'account',
      'update',
      'confirm',
      'banking',
      'password',
      'credential',
      'authenticate',
      'wallet',
      'payment',
    ];
    final matches = sensitivePatterns.where((p) => path.contains(p));
    if (matches.length >= 2) {
      return _ScoredWarning(
        score: 15,
        warning: WarningIndicator(
          title: 'Sensitive action keywords in URL path',
          description:
              'The path contains multiple credential/financial keywords '
              '(${matches.join(", ")}). This is common in phishing URLs '
              'designed to look like real login pages.',
          icon: Icons.warning_amber,
        ),
      );
    }
    return null;
  }

  // ─── Punycode / homoglyph ──────────────────────────────────────────────────

  static bool _hasPunycodeOrHomoglyphs(String host) {
    return host.contains('xn--');
  }

  // ─── Risk calculation ──────────────────────────────────────────────────────

  static RiskLevel _calculateRiskLevel(int score) {
    if (score >= 80) return RiskLevel.critical;
    if (score >= 55) return RiskLevel.high;
    if (score >= 35) return RiskLevel.medium;
    if (score >= 15) return RiskLevel.low;
    return RiskLevel.safe;
  }

  // ─── Result text ───────────────────────────────────────────────────────────

  static String _titleForRisk(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No Obvious Threats Detected';
      case RiskLevel.low:
        return 'Minor Concerns — Proceed With Caution';
      case RiskLevel.medium:
        return 'Moderate Risk — Suspicious Indicators';
      case RiskLevel.high:
        return 'Suspicious URL — Likely Phishing';
      case RiskLevel.critical:
        return 'High Risk — Avoid This URL';
    }
  }

  static String _descriptionForRisk(RiskLevel level, int warningCount) {
    if (level == RiskLevel.safe) {
      return 'No known threat indicators were found using local heuristic rules. '
          'This does NOT guarantee the destination is safe — always verify the '
          'identity of a website before entering sensitive information.';
    }
    return 'Local heuristic analysis detected $warningCount indicator(s) '
        'associated with phishing or malicious websites. '
        'This analysis was performed entirely on-device and does not include '
        'live threat-intelligence verification.';
  }

  static String _urlRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No immediate red flags, but always verify the padlock icon and '
            'exact domain in your browser before entering credentials.';
      case RiskLevel.low:
        return 'Exercise normal caution. If you must visit this site, avoid '
            'entering personal or financial information.';
      case RiskLevel.medium:
        return 'Consider avoiding this URL. If you need to access the service, '
            'navigate to the official website directly through a search engine '
            'or your own bookmarks.';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'Do NOT visit this URL or enter any information. If you believe '
            'you have already been phished, change your passwords immediately '
            'and contact your bank. Report to cybercrime.gov.in or call 1930.';
    }
  }

  // ─── Error result ──────────────────────────────────────────────────────────

  static ScanResult _parsingError(String rawInput) {
    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.link,
      riskLevel: RiskLevel.medium,
      riskScore: 40,
      title: 'Could Not Parse URL',
      description:
          'The input could not be parsed as a valid URL. This may indicate '
          'a malformed or obfuscated link designed to bypass validation.',
      warnings: const [
        WarningIndicator(
          title: 'Malformed URL',
          description:
              'The input did not conform to a standard URL format after '
              'normalization. Exercise caution with links that cannot be parsed.',
          icon: Icons.link_off,
        ),
      ],
      recommendation:
          'Do not open links you cannot identify. If you received this link '
          'in a message, treat it as suspicious.',
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: rawInput,
    );
  }
}

// ─── Internal helpers ──────────────────────────────────────────────────────

class _ScoredWarning {
  final int score;
  final WarningIndicator warning;
  const _ScoredWarning({required this.score, required this.warning});
}

class _BrandWarning {
  final int score;
  final String brand;
  final WarningIndicator warning;
  const _BrandWarning({
    required this.score,
    required this.brand,
    required this.warning,
  });
}
