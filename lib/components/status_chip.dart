import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';

/// A compact status chip for displaying risk levels
class StatusChip extends StatelessWidget {
  final RiskLevel riskLevel;
  final bool compact;

  const StatusChip({super.key, required this.riskLevel, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor, label) = _getRiskStyle();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color, String) _getRiskStyle() {
    switch (riskLevel) {
      case RiskLevel.safe:
        return (const Color(0xFFDCFCE7), const Color(0xFF16A34A), 'SAFE');
      case RiskLevel.low:
        return (const Color(0xFFDBEAFE), const Color(0xFF2563EB), 'LOW');
      case RiskLevel.medium:
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'RISKY');
      case RiskLevel.high:
        return (const Color(0xFFFED7AA), const Color(0xFFEA580C), 'WARNING');
      case RiskLevel.critical:
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'BLOCKED');
    }
  }
}
