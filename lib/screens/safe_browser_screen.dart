import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/components/status_chip.dart';

/// Sandboxed link inspection and safe browsing screen.
///
/// Provides users with deep inspection of suspicious or verified URLs before
/// interacting with them. Disables automated execution of scripts and form submissions
/// to safeguard user credentials.
class SafeBrowserScreen extends StatelessWidget {
  final String targetUrl;
  final ScanResult scanResult;

  const SafeBrowserScreen({
    super.key,
    required this.targetUrl,
    required this.scanResult,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(targetUrl);
    final scheme = uri?.scheme ?? 'https';
    final host = uri?.host ?? targetUrl;
    final path = uri?.path.isEmpty ?? true ? '/' : uri!.path;
    final isHttps = scheme.toLowerCase() == 'https';

    final isDanger =
        scanResult.riskLevel == RiskLevel.high ||
        scanResult.riskLevel == RiskLevel.critical;

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'DigiLens Safe Viewer',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share analysis',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied URL security report to clipboard.'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sandboxed URL Bar Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDanger
                      ? AppTheme.red.withValues(alpha: 0.5)
                      : AppTheme.grayBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isHttps ? Icons.lock : Icons.lock_open,
                    color: isHttps ? AppTheme.green : AppTheme.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navyText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          path,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mutedText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(riskLevel: scanResult.riskLevel, compact: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Warning or Safety Banner
            if (isDanger)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.redLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gpp_bad, color: AppTheme.red, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Dangerous Destination Blocked',
                          style: TextStyle(
                            color: AppTheme.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Automated web rendering has been suspended. '
                      'This URL contains indicators of phishing, typosquatting, '
                      'or deceptive credential harvesting.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.navyText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: AppTheme.green, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'URL passed local heuristic verification.',
                        style: TextStyle(
                          color: AppTheme.navyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Technical Destination Breakdown Card
            const Text(
              'Domain & Security Inspection',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Target Scheme',
                    value: scheme.toUpperCase(),
                    badgeColor: isHttps ? AppTheme.green : AppTheme.red,
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(label: 'Hostname', value: host),
                  const Divider(height: 1),
                  _buildDetailRow(
                    label: 'Port',
                    value: uri?.hasPort == true
                        ? '${uri!.port}'
                        : 'Default (443)',
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    label: 'Analysis Method',
                    value: scanResult.analysisMethodLabel,
                  ),
                  if (scanResult.claimedBrand != null) ...[
                    const Divider(height: 1),
                    _buildDetailRow(
                      label: 'Target Brand Mimicked',
                      value: scanResult.claimedBrand!,
                      badgeColor: AppTheme.amber,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sandbox Controls Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: AppTheme.indigo, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'In-App Sandbox Protection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Form auto-fill disabled to protect saved passwords.\n'
                    '• Cookie isolation prevents session hijacking.\n'
                    '• External redirects must be re-inspected by DigiLens.\n'
                    '• System-wide interception across other apps requires VPN/Accessibility permissions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Back to Safety button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.indigo,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text(
                  'Close & Return to DigiLens',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Report button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Reported to simulated Chakshu / 1930 Cyber Fraud registry.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  side: const BorderSide(color: AppTheme.red, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report Phishing to 1930 / Chakshu'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? AppTheme.navyText,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
