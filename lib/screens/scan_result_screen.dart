import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/components/status_chip.dart';
import 'package:digilens/services/pre_navigation_guard.dart';

class ScanResultScreen extends StatelessWidget {
  final ScanResult result;
  final String scannedInput;

  const ScanResultScreen({
    super.key,
    required this.result,
    required this.scannedInput,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDanger =
        result.riskLevel == RiskLevel.high ||
        result.riskLevel == RiskLevel.critical;
    final isSafe = result.riskLevel == RiskLevel.safe;

    final bannerColor = isDanger
        ? AppTheme.red
        : isSafe
        ? AppTheme.green
        : AppTheme.amber;

    final bannerBg = isDanger
        ? AppTheme.redLight
        : isSafe
        ? AppTheme.greenLight
        : AppTheme.amberLight;

    final bannerIcon = isDanger
        ? Icons.gpp_bad_rounded
        : isSafe
        ? Icons.verified_user_rounded
        : Icons.warning_amber_rounded;

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: Text(
          result.type == ScanType.link
              ? 'Link Analysis Results'
              : 'SMS Analysis Results',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analysis method badge
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.amberLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 14,
                    color: AppTheme.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    result.analysisMethodLabel.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Risk Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: bannerColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(bannerIcon, color: bannerColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bannerColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Risk Status: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            StatusChip(riskLevel: result.riskLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (result.type == ScanType.sms) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grayBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_pin_outlined,
                          size: 16,
                          color: AppTheme.indigo,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sender: ${_maskSender(result.sender ?? "Unknown")}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navyText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: AppTheme.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(result.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Scanned Input Card
            Text('Analyzed Input', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: Text(
                scannedInput,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppTheme.navyText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Why we flagged it / Description
            Text(
              'Why we flagged it (Analysis Signals)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: Text(
                result.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.navyLight,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Warning indicators list
            if (result.warnings.isNotEmpty) ...[
              Text(
                'Specific Indicators Found (${result.warnings.length})',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              ...result.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                warning.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.navyText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                warning.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Recommendation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.indigo.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.indigo,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Recommended Action',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.recommendation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.navyText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (result.type == ScanType.link) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    PreNavigationGuard.navigateWithProtection(
                      context,
                      targetUrl: scannedInput,
                      existingResult: result,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.indigo,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('Open in Protected Browser'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navyText,
                  side: const BorderSide(
                    color: AppTheme.grayBorder,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Safety'),
              ),
            ),
            const SizedBox(height: 12),

            // Optional continue anyway (for risky / demo)
            if (isDanger) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _showRiskConfirmation(context, scannedInput),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.red,
                    side: const BorderSide(color: AppTheme.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue anyway (High Risk)'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Report button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Reported to simulated Chakshu / National Cyber Crime Portal (1930).',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navyText,
                  side: const BorderSide(
                    color: AppTheme.grayBorder,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report to Chakshu / 1930'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showRiskConfirmation(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.red, size: 24),
            SizedBox(width: 10),
            Text('Proceed at Your Own Risk?'),
          ],
        ),
        content: Text(
          'This link was flagged as ${result.riskLevel.name.toUpperCase()}.\n\n'
          'Visiting untrusted URLs can compromise your personal data, credentials, and bank account.\n\n'
          'Target URL: $url',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back (Safe)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              Navigator.pop(context);
              PreNavigationGuard.navigateWithProtection(
                context,
                targetUrl: url,
                existingResult: result,
              );
            },
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );
  }

  String _maskSender(String sender) {
    final digits = sender.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final prefix = sender.startsWith('+') ? '${sender.substring(0, 3)} ' : '';
      final last10 = digits.substring(digits.length - 10);
      return '$prefix${last10.substring(0, 2)}******${last10.substring(8)}';
    }
    return sender;
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year;
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
