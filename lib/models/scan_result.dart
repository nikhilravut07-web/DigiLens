import 'package:flutter/material.dart';

/// The method used to produce an analysis result.
enum AnalysisMethod {
  /// Local heuristic rules only (pattern matching, keyword detection).
  localHeuristics,

  /// A trained ML model running on-device or via backend.
  mlModel,

  /// A live lookup against a threat-intelligence API.
  threatIntelligence,

  /// Simulated / demo result for demonstration purposes.
  simulated,
}

/// Types of scans supported by DigiLens.
enum ScanType { link, sms, voice }

/// Risk levels for detected threats.
enum RiskLevel { safe, low, medium, high, critical }

/// A single piece of evidence found during analysis.
class WarningIndicator {
  final String title;
  final String description;
  final IconData icon;

  const WarningIndicator({
    required this.title,
    required this.description,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {'title': title, 'description': description, 'icon': icon.codePoint};
  }

  factory WarningIndicator.fromJson(Map<String, dynamic> json) {
    return WarningIndicator(
      title: json['title'],
      description: json['description'],
      icon: const IconData(0xe88a, fontFamily: 'MaterialIcons'),
    );
  }
}

/// Represents a scan result from the analysis engine.
class ScanResult {
  final String id;
  final DateTime timestamp;
  final ScanType type;
  final RiskLevel riskLevel;
  final String title;
  final String description;
  final List<WarningIndicator> warnings;
  final String recommendation;
  final String? claimedBrand;

  /// The numeric risk score (0–100+) produced by the engine.
  final int riskScore;

  /// Which analysis pipeline produced this result.
  final AnalysisMethod analysisMethod;

  /// Original user input (URL or message text).
  /// Stored for history display; passwords/OTPs should NOT be stored.
  final String? originalInput;

  /// URLs extracted from the scanned content.
  final List<String> extractedUrls;

  const ScanResult({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.riskLevel,
    required this.title,
    required this.description,
    required this.warnings,
    required this.recommendation,
    this.claimedBrand,
    this.riskScore = 0,
    this.analysisMethod = AnalysisMethod.localHeuristics,
    this.originalInput,
    this.extractedUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'riskLevel': riskLevel.name,
      'title': title,
      'description': description,
      'warnings': warnings.map((w) => w.toJson()).toList(),
      'recommendation': recommendation,
      if (claimedBrand != null) 'claimedBrand': claimedBrand,
      'riskScore': riskScore,
      'analysisMethod': analysisMethod.name,
      'extractedUrls': extractedUrls,
    };
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: ScanType.values.byName(json['type']),
      riskLevel: RiskLevel.values.byName(json['riskLevel']),
      title: json['title'],
      description: json['description'],
      warnings: (json['warnings'] as List)
          .map((w) => WarningIndicator.fromJson(w))
          .toList(),
      recommendation: json['recommendation'],
      claimedBrand: json['claimedBrand'] as String?,
      riskScore: json['riskScore'] ?? 0,
      analysisMethod: json['analysisMethod'] != null
          ? AnalysisMethod.values.byName(json['analysisMethod'])
          : AnalysisMethod.localHeuristics,
      extractedUrls: json['extractedUrls'] != null
          ? List<String>.from(json['extractedUrls'])
          : const [],
    );
  }

  /// Human-readable label for the analysis method.
  String get analysisMethodLabel {
    switch (analysisMethod) {
      case AnalysisMethod.localHeuristics:
        return 'Local heuristic rules';
      case AnalysisMethod.mlModel:
        return 'ML model';
      case AnalysisMethod.threatIntelligence:
        return 'Threat intelligence API';
      case AnalysisMethod.simulated:
        return 'Simulated (demo)';
    }
  }
}
