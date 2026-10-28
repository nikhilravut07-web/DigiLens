import 'package:flutter/material.dart';
import 'package:digilens/components/status_chip.dart';
import 'package:digilens/screens/link_scanner_screen.dart';
import 'package:digilens/screens/sms_analyzer_screen.dart';
import 'package:digilens/screens/voice_analyzer_screen.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, greeting)),
            SliverToBoxAdapter(child: _buildProtectionCard(context)),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverToBoxAdapter(child: _buildRecentActivity(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String greeting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          // Left: greeting + title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'DigiLens',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyText,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Right: demo badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.amberLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_outlined, size: 12, color: AppTheme.amber),
                SizedBox(width: 4),
                Text(
                  'DEMO',
                  style: TextStyle(
                    color: AppTheme.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Protection summary card ───────────────────────────────────────────────

  Widget _buildProtectionCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.indigo.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Shield icon container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shield, color: AppTheme.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sample: 1 scam link checked today',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You checked 3 things. Keep checking\nbefore you tap.',
                    style: TextStyle(
                      color: AppTheme.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Scan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickActionButton(
                icon: Icons.link_rounded,
                label: 'Link',
                color: AppTheme.indigo,
                background: const Color(0xFFEDE9FE),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LinkScannerScreen()),
                ),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.sms_outlined,
                label: 'Message',
                color: const Color(0xFF0EA5E9),
                background: const Color(0xFFE0F2FE),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmsAnalyzerScreen()),
                ),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.phone_outlined,
                label: 'Call',
                color: const Color(0xFFF59E0B),
                background: const Color(0xFFFEF3C7),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoiceAnalyzerScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.qr_code_scanner,
                label: 'QR Code',
                color: const Color(0xFF22C55E),
                background: const Color(0xFFDCFCE7),
                onTap: () => _showQrPlaceholder(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQrPlaceholder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF22C55E),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('QR Scanner'),
          ],
        ),
        content: const Text(
          'QR code scanning requires camera access and a dedicated scanning library.\n\n'
          'This feature is planned for a future build. For now, copy the URL from a QR code and use the Link Scanner.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkScannerScreen()),
              );
            },
            child: const Text('Open Link Scanner'),
          ),
        ],
      ),
    );
  }

  // ─── Recent Activity ──────────────────────────────────────────────────────

  Widget _buildRecentActivity(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyText,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  // Pop to root so user can tap History in bottom nav
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap "History" in the bottom navigation'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.indigo,
                  ),
                ),
              ),
            ],
          ),

          // Demo label
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.amberLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'SAMPLE DATA — not from real scans',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.amber,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          _ActivityRow(
            icon: Icons.link,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            title: 'sbi-update-kyc.xyz',
            subtitle: 'Possible typosquatting · .xyz domain',
            riskLevel: RiskLevel.critical,
            onTap: () => _openSampleResult(
              context,
              input: 'https://sbi-update-kyc.xyz/login',
              scanType: ScanType.link,
              riskLevel: RiskLevel.critical,
              title: 'High Risk URL — Phishing Detected',
              description: 'Analysis detected multiple red flags including untrusted .xyz TLD and a domain name that mimics the State Bank of India. This is DEMO analysis — not live verification.',
              warnings: const [
                WarningIndicator(
                  title: 'Unusual domain extension (.xyz)',
                  description:
                      'Commonly used by low-cost disposable phishing sites.',
                  icon: Icons.dns,
                ),
                WarningIndicator(
                  title: 'Possible typosquatting',
                  description: 'Domain resembles "sbi" without official sbi.co.in authorization.',
                  icon: Icons.domain,
                ),
              ],
              recommendation: 'Do not click or enter bank credentials. Report to cybercrime.gov.in.',
            ),
          ),
          const SizedBox(height: 8),

          _ActivityRow(
            icon: Icons.sms,
            iconColor: const Color(0xFFEA580C),
            iconBg: const Color(0xFFFED7AA),
            title: 'Unknown number · Electricity bill',
            subtitle: '"Power disconnected at 9 PM…"',
            riskLevel: RiskLevel.high,
            onTap: () => _openSampleResult(
              context,
              input: 'URGENT: Your electricity connection will be disconnected tonight at 9:30 PM. Call 9876543210.',
              scanType: ScanType.sms,
              riskLevel: RiskLevel.high,
              title: 'Suspicious Utility Extortion SMS',
              description: 'Contains high-pressure deadline and a personal mobile number disguised as a power utility helpline. DEMO analysis only.',
              warnings: const [
                WarningIndicator(
                  title: 'Manufactured urgency',
                  description: 'Sets immediate time limit to trigger panic.',
                  icon: Icons.schedule,
                ),
                WarningIndicator(
                  title: 'Personal contact number',
                  description: 'Official boards use registered shortcodes, not 10-digit mobiles.',
                  icon: Icons.phone_android,
                ),
              ],
              recommendation: 'Do not call or pay. Verify dues only via your state discom\'s official portal.',
            ),
          ),
          const SizedBox(height: 8),

          _ActivityRow(
            icon: Icons.link,
            iconColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFFDCFCE7),
            title: 'incometax.gov.in',
            subtitle: 'Verified .gov.in domain · Government',
            riskLevel: RiskLevel.safe,
            onTap: () => _openSampleResult(
              context,
              input: 'https://www.incometax.gov.in',
              scanType: ScanType.link,
              riskLevel: RiskLevel.safe,
              title: 'No Obvious Threats Detected',
              description: 'The URL uses a .gov.in domain (reserved for Indian government bodies). No suspicious patterns were flagged. DEMO analysis only — always verify the padlock in your browser.',
              warnings: const [],
              recommendation: 'URL passed basic checks. Always verify the padlock icon in your browser address bar.',
            ),
          ),
        ],
      ),
    );
  }

  void _openSampleResult(
    BuildContext context, {
    required String input,
    required ScanType scanType,
    required RiskLevel riskLevel,
    required String title,
    required String description,
    required List<WarningIndicator> warnings,
    required String recommendation,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          scannedInput: input,
          result: ScanResult(
            id: 'sample-${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
            type: scanType,
            riskLevel: riskLevel,
            title: title,
            description: description,
            warnings: warnings,
            recommendation: recommendation,
          ),
        ),
      ),
    );
  }
}

// ─── Quick Action Button ─────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.grayBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navyText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Activity Row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final RiskLevel riskLevel;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.riskLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.grayBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navyText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            StatusChip(riskLevel: riskLevel),
          ],
        ),
      ),
    );
  }
}
