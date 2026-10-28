import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';

import 'voice_classifier_interface.dart';

/// Rule-based heuristic implementation of [VoiceTranscriptClassifier].
///
/// NOTE: This performs TEXT-BASED analysis of call transcripts provided by
/// the user. It does NOT perform acoustic voice analysis, speech-to-text,
/// deepfake audio detection, or live call interception.
class VoiceAnalysisService implements VoiceTranscriptClassifier {
  static final math.Random _random = math.Random();

  @override
  String get name => 'Rule-based Voice Transcript Heuristics v1.0';

  @override
  AnalysisMethod get method => AnalysisMethod.localHeuristics;

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (i) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Analyze a transcribed call text for social engineering and vishing patterns.
  @override
  Future<ScanResult> classifyTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return _emptyResult(transcript);
    }

    final lower = trimmed.toLowerCase();
    int riskScore = 0;
    final warnings = <WarningIndicator>[];

    // ── 1. Digital Arrest & Fake Legal Threats ─────────────────────────────
    const digitalArrestKeywords = [
      'digital arrest',
      'arrest warrant',
      'customs parcel',
      'illegal parcel',
      'drugs found',
      'passport seized',
      'contraband',
      'narcotics',
      'cbi officer',
      'cyber cell',
      'police commissioner',
      'police officer',
      'under arrest',
      'customs officer',
      'ed notice',
      'supreme court order',
      'court notice',
      'money laundering',
    ];
    if (digitalArrestKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 45;
      warnings.add(
        const WarningIndicator(
          title: 'Digital arrest / Law enforcement impersonation',
          description:
              'Claims that you are under "digital arrest" or facing an arrest warrant '
              'from CBI, Police, Customs, or NCB. Indian law enforcement agencies NEVER '
              'conduct arrests or interrogation via video or phone calls.',
          icon: Icons.gavel,
        ),
      );
    }

    // ── 2. Coercion: Do Not Disconnect / Secrecy ──────────────────────────
    const isolationKeywords = [
      'do not disconnect',
      'stay on the call',
      'don\'t disconnect',
      'do not tell anyone',
      'do not inform your family',
      'keep this confidential',
      'go to a quiet room',
      'lock the door',
      'do not hang up',
    ];
    if (isolationKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Psychological isolation & coercion',
          description:
              'Instructions to stay on the line, isolate yourself in a room, or keep '
              'the conversation secret from family or lawyers are hallmarks of extortion scams.',
          icon: Icons.lock_clock,
        ),
      );
    }

    // ── 3. Demands for Money Transfer / Security Deposit ──────────────────
    const moneyTransferKeywords = [
      'transfer money',
      'security deposit',
      'verification account',
      'refundable amount',
      'rbi verification',
      'clear your name',
      'send payment',
      'rtgs',
      'neft',
      'imps',
      'upi transfer',
      'send money',
      '50,000',
      '1 lakh',
      'to verify',
      'to clear',
    ];
    // More specific phrases that clearly indicate a scam
    const specificScamPhrases = [
      'transfer 50,000',
      'transfer 1 lakh',
      'to verify your account',
      'to clear your name',
    ];
    if (specificScamPhrases.any((kw) => lower.contains(kw))) {
      riskScore += 50;
      warnings.add(
        const WarningIndicator(
          title: 'Demand for money transfer to "clear innocence"',
          description:
              'Demanding money transfers to "verify accounts" or as a "refundable security deposit" '
              'is 100% fraudulent. Government agencies never ask suspects to transfer money.',
          icon: Icons.payments_outlined,
        ),
      );
    } else if (moneyTransferKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Demand for money transfer to "clear innocence"',
          description:
              'Demanding money transfers to "verify accounts" or as a "refundable security deposit" '
              'is 100% fraudulent. Government agencies never ask suspects to transfer money.',
          icon: Icons.payments_outlined,
        ),
      );
    }

    // ── 4. Remote Access Application Installation ─────────────────────────
    const remoteAccessKeywords = [
      'anydesk',
      'teamviewer',
      'rustdesk',
      'quicksupport',
      'screen share',
      'download app',
      'install application',
      'apk file',
      'support app',
    ];
    if (remoteAccessKeywords.any((kw) => lower.contains(kw))) {
      riskScore += 35;
      warnings.add(
        const WarningIndicator(
          title: 'Remote screen-sharing app request',
          description:
              'Asking you to install remote-desktop applications (AnyDesk, TeamViewer, RustDesk, etc.) '
              'gives attackers full control of your device and mobile banking screens.',
          icon: Icons.screen_share,
        ),
      );
    }

    // ── 5. Fake Bank Officer / KYC Verification Call ───────────────────────
    // More specific patterns - require bank name + credential request together
    // Automated IVR calls (e.g. "Press 1 for details") are NOT scams
    // Scams involve personal credential requests (CVV, OTP, PIN, etc.)

    const bankNameMentions = [
      'sbi manager',
      'sbi officer',
      'hdfc manager',
      'hdfc officer',
      'this is sbi',
      'this is hdfc',
      'calling from sbi',
      'calling from hdfc',
      'calling from bank',
      'calling from your bank',
      'this is your bank',
      'bank manager',
      'bank officer',
      'icici manager',
      'axis manager',
    ];

    const credentialKeywords = [
      'cvv',
      'card number',
      'atm pin',
      'otp',
      'tell me your',
      'tell me the',
      'tell me cvv',
      'tell me otp',
      'share your',
      'provide your',
      'your card has expired',
      'card expired',
    ];

    final hasBankNameMention = bankNameMentions.any((kw) => lower.contains(kw));
    final hasCredentialRequest = credentialKeywords.any(
      (kw) => lower.contains(kw),
    );

    // Count number of distinct credential types requested
    int credentialTypes = 0;
    if (lower.contains('cvv')) credentialTypes++;
    if (lower.contains('otp')) credentialTypes++;
    if (lower.contains('pin')) credentialTypes++;
    if (lower.contains('card number')) credentialTypes++;
    if (lower.contains('password')) credentialTypes++;

    // Flag as impersonation if they ask for credentials
    if (hasCredentialRequest) {
      riskScore += 30;
      warnings.add(
        const WarningIndicator(
          title: 'Financial institution impersonation',
          description:
              'Caller claims to represent your bank asking for card details, PIN, '
              'or OTP. Bank staff never ask for authentication secrets over a call.',
          icon: Icons.account_balance,
        ),
      );
    }

    // Bonus: Bank name + credentials = clearly a scam
    if (hasBankNameMention && hasCredentialRequest) {
      riskScore += 15;
    }

    // Bonus: Multiple credential types requested = escalated threat
    if (credentialTypes >= 2) {
      riskScore += 10;
    }

    // ── Calculate risk level ───────────────────────────────────────────────
    final riskLevel = _calculateRiskLevel(riskScore);

    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.voice,
      riskLevel: riskLevel,
      riskScore: riskScore,
      title: _titleForRisk(riskLevel),
      description: _descriptionForRisk(riskLevel, warnings.length),
      warnings: warnings,
      recommendation: _voiceRecommendation(riskLevel),
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: transcript,
    );
  }

  static RiskLevel _calculateRiskLevel(int score) {
    if (score >= 70) return RiskLevel.critical;
    if (score >= 45) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    if (score >= 10) return RiskLevel.low;
    return RiskLevel.safe;
  }

  static String _titleForRisk(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'No Voice Scam Patterns Detected';
      case RiskLevel.low:
        return 'Low Threat Indicators';
      case RiskLevel.medium:
        return 'Suspicious Call Elements Detected';
      case RiskLevel.high:
        return 'High Risk — Likely Vishing / Extortion';
      case RiskLevel.critical:
        return 'Severe Threat — Extortion / Digital Arrest Scam';
    }
  }

  static String _descriptionForRisk(RiskLevel level, int warningCount) {
    if (level == RiskLevel.safe) {
      return 'The call transcript did not match known social-engineering or vishing scripts. '
          'Note: This analysis is text-only and does not inspect acoustic properties or deepfakes.';
    }
    return 'Text analysis of the call transcript identified $warningCount warning indicator(s) '
        'strongly characteristic of fraudulent phone extortion or impersonation scams.';
  }

  static String _voiceRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'If you ever feel pressured or uneasy during a phone call, hang up and call back '
            'using an official number from the organisation\'s verified website.';
      case RiskLevel.low:
        return 'Exercise caution. Never reveal confidential details (passwords, PINs, card numbers) '
            'to an incoming caller.';
      case RiskLevel.medium:
        return 'Disconnect the call immediately. Verify the caller\'s claims by contacting '
            'the organisation through their official public helpline.';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'DISCONNECT IMMEDIATELY. Do not transfer any money. '
            'There is NO SUCH THING as a "Digital Arrest". '
            'Immediately dial the National Cyber Helpline: 1930 or file a report at cybercrime.gov.in.';
    }
  }

  static ScanResult _emptyResult(String rawInput) {
    return ScanResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: ScanType.voice,
      riskLevel: RiskLevel.safe,
      riskScore: 0,
      title: 'Empty Call Transcript',
      description: 'No transcript text was provided for analysis.',
      warnings: const [],
      recommendation:
          'Paste or type a transcript of the conversation to analyze.',
      analysisMethod: AnalysisMethod.localHeuristics,
      originalInput: rawInput,
    );
  }
}
