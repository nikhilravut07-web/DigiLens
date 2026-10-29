import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/models/scan_result.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  @override
  void initState() {
    super.initState();
    ScanHistoryService.instance.historyNotifier.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    ScanHistoryService.instance.historyNotifier.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Performance & Live Stats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildLiveScanStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildLiveScanStatisticsCard() {
    // Filter history to URL scans only per requirement 4
    final historyItems = ScanHistoryService.instance.items
        .where((item) => item.result.type == ScanType.link)
        .toList();

    final totalScans = historyItems.length;

    int safeCount = 0;
    int suspiciousCount = 0;
    int maliciousCount = 0;
    int errorCount = 0;
    final Set<String> uniqueInputs = {};

    for (final item in historyItems) {
      uniqueInputs.add(item.sanitizedInput);
      final risk = item.result.riskLevel;
      if (risk == RiskLevel.safe || risk == RiskLevel.low) {
        safeCount++;
      } else if (risk == RiskLevel.medium) {
        suspiciousCount++;
      } else if (risk == RiskLevel.high || risk == RiskLevel.critical) {
        maliciousCount++;
      }
      if (item.result.title.toLowerCase().contains('error') ||
          item.result.title.toLowerCase().contains('fail') ||
          item.result.title.toLowerCase().contains('malformed')) {
        errorCount++;
      }
    }

    final threatCount = suspiciousCount + maliciousCount;
    final detectionRate = totalScans > 0 ? (threatCount / totalScans) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: AppTheme.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Live URL Scan Statistics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navyText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aggregated from actual on-device URL scans. Precision, recall, and false positive rate require independent ground truth and are not estimated from model predictions alone.',
            style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricTile('Total Scans', '$totalScans', 'Recorded URL logs')),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile('Unique URLs', '${uniqueInputs.length}', 'Distinct targets')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCell('Safe / Low', '$safeCount', AppTheme.greenLight, AppTheme.green)),
              const SizedBox(width: 10),
              Expanded(child: _buildCell('Suspicious', '$suspiciousCount', Colors.orange[50]!, Colors.orange[800]!)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCell('Malicious / Critical', '$maliciousCount', AppTheme.redLight, AppTheme.red)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Flagged Rate', '${detectionRate.toStringAsFixed(1)}%', 'Suspicious + Malicious')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCell('Errors / Failed', '$errorCount', AppTheme.grayBorder, AppTheme.mutedText)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Unique Share', totalScans > 0 ? '${((uniqueInputs.length / totalScans) * 100).toStringAsFixed(0)}%' : '0%', 'Diversity ratio')),
            ],
          ),
          const SizedBox(height: 16),
          // Ground Truth Unavailability & Professional Metrics Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lavenderBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.grayBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Independent Ground Truth Metrics',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navyText),
                ),
                SizedBox(height: 6),
                Text('• Precision: Ground truth required', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                Text('• Recall: Ground truth required', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                Text('• False Positive Rate: Ground truth required', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
              ],
            ),
          ),
          if (historyItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Recent URL Scan Activity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navyText),
            ),
            const SizedBox(height: 8),
            ...historyItems.take(3).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      item.result.riskLevel == RiskLevel.critical || item.result.riskLevel == RiskLevel.high
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                      size: 16,
                      color: item.result.riskLevel == RiskLevel.critical || item.result.riskLevel == RiskLevel.high
                          ? AppTheme.red
                          : AppTheme.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.sanitizedInput,
                        style: const TextStyle(fontSize: 12, color: AppTheme.navyText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(item.result.timestamp),
                      style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inMinutes < 60) {
      return '${now.difference(dt).inMinutes}m ago';
    }
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMetricTile(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.mutedText)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.mutedText)),
        ],
      ),
    );
  }

  Widget _buildCell(String label, String count, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
        ],
      ),
    );
  }
}
