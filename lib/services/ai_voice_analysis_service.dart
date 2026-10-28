import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:digilens/models/scan_result.dart';
import 'voice_classifier_interface.dart';
import 'voice_analysis_service.dart';

/// Contextual AI Voice Scam Analysis Service that mediates with the backend
/// and falls back gracefully to local heuristic rules when offline or unavailable.
class AiVoiceAnalysisService implements VoiceTranscriptClassifier {
  final String backendUrl;
  final VoiceAnalysisService _fallbackService;
  final http.Client? _clientOverride;

  AiVoiceAnalysisService({
    this.backendUrl = 'http://10.0.2.2:8000/api/v1/analyze-voice',
    VoiceAnalysisService? fallbackService,
    http.Client? client,
  })  : _fallbackService = fallbackService ?? VoiceAnalysisService(),
        _clientOverride = client;

  @override
  String get name => 'Hybrid Gemini AI + Local Heuristics v1.0';

  @override
  AnalysisMethod get method => AnalysisMethod.mlModel;

  @override
  Future<ScanResult> classifyTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return _fallbackService.classifyTranscript(transcript);
    }

    final client = _clientOverride ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcript': trimmed,
          'language': 'en-IN',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseBackendResponse(data, transcript);
      }
    } catch (_) {
      // Network failure, timeout, or backend offline: gracefully fallback to local rules
    } finally {
      if (_clientOverride == null) {
        client.close();
      }
    }

    // Fallback to local heuristic rules
    return _fallbackService.classifyTranscript(transcript);
  }

  ScanResult _parseBackendResponse(Map<String, dynamic> data, String rawTranscript) {
    final riskLevelStr = (data['risk_level'] as String? ?? 'safe').toLowerCase();
    RiskLevel riskLevel;
    switch (riskLevelStr) {
      case 'critical':
        riskLevel = RiskLevel.critical;
        break;
      case 'high':
        riskLevel = RiskLevel.high;
        break;
      case 'medium':
        riskLevel = RiskLevel.medium;
        break;
      case 'low':
        riskLevel = RiskLevel.low;
        break;
      default:
        riskLevel = RiskLevel.safe;
    }

    final riskScore = (data['risk_score'] as num? ?? 0).toInt();
    final scamType = data['scam_type'] as String? ?? 'unknown';
    final recommendedAction = data['recommended_action'] as String? ?? 'Exercise caution.';

    final warnings = <WarningIndicator>[];
    if (data['evidence'] is List) {
      for (final item in data['evidence'] as List) {
        if (item is Map<String, dynamic>) {
          warnings.add(
            WarningIndicator(
              title: item['title'] as String? ?? 'Scam Indicator',
              description: item['description'] as String? ?? '',
              icon: Icons.warning_amber_rounded,
            ),
          );
        }
      }
    }

    String title;
    switch (scamType) {
      case 'digital_arrest':
        title = 'Digital Arrest & Law Enforcement Scam Detected';
        break;
      case 'bank_impersonation':
        title = 'Bank Officer Impersonation Detected';
        break;
      case 'otp_theft':
        title = 'OTP & Authentication Credential Theft';
        break;
      case 'remote_access':
        title = 'Remote Access Application Installation Demand';
        break;
      case 'money_demand':
        title = 'Extortion & Unverified Money Transfer Demand';
        break;
      default:
        title = riskLevel == RiskLevel.safe
            ? 'No Voice Scam Patterns Detected'
            : 'Suspicious Call Elements Detected';
    }

    return ScanResult(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: ScanType.voice,
      riskLevel: riskLevel,
      riskScore: riskScore,
      title: title,
      description: warnings.isNotEmpty
          ? warnings.first.description
          : 'Contextual AI analysis detected scam patterns.',
      warnings: warnings,
      recommendation: recommendedAction,
      analysisMethod: AnalysisMethod.mlModel,
      originalInput: rawTranscript,
    );
  }
}
