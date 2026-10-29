import 'package:flutter/material.dart';
import 'package:digilens/components/status_chip.dart';
import 'package:digilens/screens/link_scanner_screen.dart';
import 'package:digilens/screens/sms_analyzer_screen.dart';
import 'package:digilens/screens/voice_analyzer_screen.dart';
import 'package:digilens/screens/qr_scanner_screen.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DigiLens',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
            ),
            Text(
              'Cybersecurity & Scam Shield',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProtectionOverview(context),
            const SizedBox(height: 24),
            _buildQuickScanSection(context),
            const SizedBox(height: 24),
            _buildRecentActivitySection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Protection Overview Card ─────────────────────────────────────────────

  Widget _buildProtectionOverview(BuildContext context) {
    final smsActive = AutomaticSmsGuardService.instance.isProtectionEnabled;
    final parentalActive = ParentalControlService.instance.isEnabled;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.security, color: AppTheme.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Active System Protection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatusPill(
                  title: 'SMS Scam Guard',
                  isActive: smsActive,
                  activeLabel: 'Active',
                  inactiveLabel: 'Standby',
                  icon: Icons.sms_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatusPill(
                  title: 'Parental Web Guard',
                  isActive: parentalActive,
                  activeLabel: 'Enforced',
                  inactiveLabel: 'Disabled',
                  icon: Icons.family_restroom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String title,
    required bool isActive,
    required String activeLabel,
    required String inactiveLabel,
    required IconData icon,
  }) {
    final color = isActive ? AppTheme.green : AppTheme.mutedText;
    final bgColor = isActive ? AppTheme.greenLight : AppTheme.grayBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navyText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isActive ? activeLabel : inactiveLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Scan Section ───────────────────────────────────────────────────

  Widget _buildQuickScanSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Scan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.navyText,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickScanTile(
                icon: Icons.link_rounded,
                label: 'Link',
                color: AppTheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LinkScannerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickScanTile(
                icon: Icons.sms_outlined,
                label: 'Message',
                color: const Color(0xFF0284C7),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmsAnalyzerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickScanTile(
                icon: Icons.phone_outlined,
                label: 'Call',
                color: const Color(0xFFD97706),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceAnalyzerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickScanTile(
                icon: Icons.qr_code_scanner,
                label: 'QR Code',
                color: AppTheme.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Recent Scans Section ─────────────────────────────────────────────────

  Widget _buildRecentActivitySection(BuildContext context) {
    return ValueListenableBuilder<List<ScanHistoryItem>>(
      valueListenable: ScanHistoryService.instance.historyNotifier,
      builder: (context, items, _) {
        final recentItems = items.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} ${items.length == 1 ? "Scan" : "Scans"} Performed',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.grayBorder),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 36,
                      color: AppTheme.mutedText,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No Scans Performed Yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Analyze a link, SMS message, or call transcript above to record security scans.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...recentItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.grayBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: StatusChip(riskLevel: item.result.riskLevel, compact: true),
                      title: Text(
                        item.result.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sanitizedInput,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.source != null && item.source!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Via ${item.source}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppTheme.mutedText,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScanResultScreen(
                              result: item.result,
                              scannedInput: item.sanitizedInput,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _QuickScanTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickScanTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grayBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
