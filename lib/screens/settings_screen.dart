import 'package:flutter/material.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/screens/parental_pin_setup_screen.dart';
import 'package:digilens/screens/parental_history_screen.dart';
import 'package:digilens/components/parental_pin_modal.dart';
import 'package:digilens/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSms = AutomaticSmsGuardService.instance.isProtectionEnabled;
  bool _cloudAi = AutomaticSmsGuardService.instance.isCloudAiEnabled;
  bool _parentalEnabled = ParentalControlService.instance.isEnabled;

  @override
  void initState() {
    super.initState();
    _refreshParentalState();
  }

  void _refreshParentalState() {
    setState(() {
      _parentalEnabled = ParentalControlService.instance.isEnabled;
    });
  }

  Future<void> _handleParentalToggle(bool value) async {
    final hasPin = await ParentalControlService.instance.hasPinSet();
    if (!mounted) return;

    if (!hasPin) {
      // Direct user to PIN setup screen first
      final setupSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const ParentalPinSetupScreen(isChangePin: false),
        ),
      );

      if (setupSuccess == true && mounted) {
        // Once PIN is setup, verify to enable
        await ParentalControlService.instance.setEnabled(true);
        if (!mounted) return;
        _refreshParentalState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parental Control is now enabled.')),
        );
      }
      return;
    }

    // Require PIN verification to toggle
    final verified = await ParentalPinModal.show(
      context,
      title: value ? 'Enable Parental Controls' : 'Disable Parental Controls',
      subtitle: 'Enter your 6-digit parental PIN to confirm this change.',
    );

    if (verified && mounted) {
      await ParentalControlService.instance.setEnabled(value);
      if (!mounted) return;
      _refreshParentalState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Parental Control is now active.'
                : 'Parental Control has been disabled.',
          ),
        ),
      );
    }
  }

  Future<void> _handleChangePin() async {
    final hasPin = await ParentalControlService.instance.hasPinSet();
    if (!mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ParentalPinSetupScreen(isChangePin: hasPin),
      ),
    );
    _refreshParentalState();
  }

  Future<void> _openHistory() async {
    final verified = await ParentalPinModal.show(
      context,
      title: 'Parental Activity Log',
      subtitle: 'Enter your 6-digit PIN to review browsing and approval history.',
    );

    if (verified && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ParentalHistoryScreen(),
        ),
      );
    }
  }

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

          // Parental Control Section
          const Text(
            'Parental Control & Safe Browsing',
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
                    Icons.family_restroom,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Parental Web Guard',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _parentalEnabled
                        ? 'Active: PIN approval required to open websites'
                        : 'Disabled: In-app links open directly',
                    style: TextStyle(
                      fontSize: 12,
                      color: _parentalEnabled ? Colors.green[700] : AppTheme.mutedText,
                      fontWeight: _parentalEnabled ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: _parentalEnabled,
                  onChanged: (val) => _handleParentalToggle(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.pin_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Parental 6-Digit PIN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Create or update secure access PIN',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.mutedText,
                  ),
                  onTap: _handleChangePin,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.manage_history_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Activity History & Audit Log',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Review website access attempts and PIN logs',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.mutedText,
                  ),
                  onTap: _openHistory,
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
            icon: Icons.phonelink_lock,
            title: 'Parental Control In-App Scope',
            description: 'Parental Control intercepts links and web navigation initiated within DigiLens. System-wide website blocking in Chrome or 3rd-party apps requires Android VPN/Accessibility service permissions and is not implemented in this prototype.',
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
            title: 'Privacy & Data Protection',
            description: 'DigiLens intercepts only newly incoming SMS broadcasts via system receiver with your explicit permission. Scans mask OTPs, credit cards, and sensitive identifiers. Data is analyzed contextually with on-device heuristics or Gemini AI with your opt-in.',
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
                    Icons.security_update_good_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Automatic SMS Scam Guard',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Intercept & scan incoming SMS messages',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _autoSms,
                  onChanged: (val) async {
                    if (val) {
                      final messenger = ScaffoldMessenger.of(context);
                      final perms = await AutomaticSmsGuardService.instance.requestPermissions();
                      if (perms['sms'] != true) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('SMS permission is required.')),
                        );
                        return;
                      }
                    }
                    if (!mounted) return;
                    setState(() {
                      _autoSms = val;
                    });
                    AutomaticSmsGuardService.instance.setProtectionEnabled(val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.cloud_sync_outlined,
                    color: AppTheme.indigo,
                  ),
                  title: const Text(
                    'Cloud AI Smishing Analysis',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Contextual Gemini 3.5 Flash analysis with local fallback',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _cloudAi,
                  onChanged: (val) {
                    setState(() {
                      _cloudAi = val;
                    });
                    AutomaticSmsGuardService.instance.setCloudAiEnabled(val);
                  },
                ),
                const Divider(height: 1),
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
