import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Settings & About',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.grayBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.indigo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: AppTheme.indigo,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'DigiLens',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'See Beyond the Screen.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version 1.0.0 (Hackathon Prototype)',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // National Cyber Emergency Support (India)
          const Text(
            'Emergency Assistance (India)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.redLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_in_talk, color: AppTheme.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'National Cyber Helpline: 1930',
                      style: TextStyle(
                        color: AppTheme.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you have been scammed or lost money in a financial fraud, dial 1930 immediately to freeze fraudulent money transfers within the "Golden Hour".',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.navyText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Online reporting: cybercrime.gov.in | Suspected fraud reporting: Chakshu (sancharsaathi.gov.in)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedText,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Prototype Limitations
          const Text(
            'Prototype Disclaimers & Limitations',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoTile(
            context,
            icon: Icons.shield_outlined,
            title: 'Simulated Detection Logic',
            description: 'This preview uses client-side heuristic rules to showcase UX and detection workflows. Ready to connect to a FastAPI machine learning backend.',
          ),
          const SizedBox(height: 10),

          _buildInfoTile(
            context,
            icon: Icons.no_accounts_outlined,
            title: 'No Official Affiliation',
            description: 'DigiLens is an independent cybersecurity prototype. It is NOT affiliated with or endorsed by RBI, NPCI, CERT-In, or any bank.',
          ),
          const SizedBox(height: 10),

          _buildInfoTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'User-Initiated Privacy',
            description: 'Scans are strictly user-initiated. DigiLens does NOT read SMS inboxes in background, intercept network packets, or monitor calls without explicit action.',
          ),
          const SizedBox(height: 24),

          // Application Settings
          const Text(
            'Application Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Fraud Alert Bulletins',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Notify when new UPI scam formats emerge',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: true,
                  onChanged: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Alert notifications ${val ? "enabled" : "disabled"}',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.offline_bolt_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Offline Heuristics Engine',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Run baseline keyword rules without internet',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.api_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Backend API Endpoint',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'http://localhost:8000 (FastAPI mock)',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.mutedText,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'FastAPI detection endpoint configurable in production build.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
