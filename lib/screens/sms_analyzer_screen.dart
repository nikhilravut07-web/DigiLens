import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/sms_analysis_service.dart';
import 'package:digilens/services/automatic_sms_guard_service.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/theme/app_theme.dart';

class SmsAnalyzerScreen extends StatefulWidget {
  const SmsAnalyzerScreen({super.key});

  @override
  State<SmsAnalyzerScreen> createState() => _SmsAnalyzerScreenState();
}

class _SmsAnalyzerScreenState extends State<SmsAnalyzerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  bool _isLoading = false;
  bool _autoSmsEnabled = AutomaticSmsGuardService.instance.isProtectionEnabled;
  bool _cloudAiEnabled = AutomaticSmsGuardService.instance.isCloudAiEnabled;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _performScan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final text = _textController.text.trim();
      ScanResult result;
      if (_cloudAiEnabled) {
        // Use automatic SMS guard service which queries cloud AI backend with fallback
        result = await AutomaticSmsGuardService.instance.processIncomingSms(
          sender: 'ManualTest',
          body: text,
          fromTap: true,
        ) ?? await SmsAnalysisService.analyzeSms(text);
      } else {
        result = await SmsAnalysisService.analyzeSms(text);
        ScanHistoryService.instance.recordScan(rawInput: text, result: result);
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ScanResultScreen(result: result, scannedInput: text),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMS analysis error: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadSample(String sampleText) {
    setState(() {
      _textController.text = sampleText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'SMS Analyzer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              color: Color(0xFF0EA5E9),
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic Smishing & SMS Guard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navyText,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Real-time incoming SMS protection with Gemini AI & local fallback.',
                                  style: TextStyle(
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
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Background SMS Monitoring',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Inspect incoming messages automatically',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _autoSmsEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final messenger = ScaffoldMessenger.of(context);
                            final perms = await AutomaticSmsGuardService.instance.requestPermissions();
                            if (perms['sms'] != true) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('SMS permission is required for automatic incoming SMS protection.')),
                              );
                              return;
                            }
                          }
                          if (!mounted) return;
                          setState(() {
                            _autoSmsEnabled = val;
                          });
                          AutomaticSmsGuardService.instance.setProtectionEnabled(val);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Cloud-Assisted AI (Gemini Flash)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Enable Cloud AI (Recommended)',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _cloudAiEnabled,
                        onChanged: (val) {
                          setState(() {
                            _cloudAiEnabled = val;
                          });
                          AutomaticSmsGuardService.instance.setCloudAiEnabled(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Input field
                Text(
                  'Paste SMS Text to analyze',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste or type an SMS message to check for common scam patterns.',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _textController,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _performScan(),
                  decoration: InputDecoration(
                    hintText: 'Paste suspicious message here...',
                    hintStyle: const TextStyle(color: AppTheme.mutedText),
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.grayBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.grayBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.indigo,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please paste or type an SMS message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Scan button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _performScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.security, size: 20),
                    label: Text(
                      _isLoading ? 'Analyzing Message…' : 'Analyze SMS',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sample chips
                Text(
                  'Try sample Indian scams (DEMO)',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.account_balance,
                        size: 14,
                        color: Colors.orange,
                      ),
                      label: const Text('Bank KYC Blocked'),
                      onPressed: () => _loadSample(
                        'Dear customer, your SBI account has been suspended due to pending KYC. Click immediately: http://sbi-kyc-update.xyz/verify',
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.bolt,
                        size: 14,
                        color: Colors.amber,
                      ),
                      label: const Text('Electricity Cut Off'),
                      onPressed: () => _loadSample(
                        'URGENT: Power disconnected at 9:30 PM due to unpaid bill. Call 9876543210.',
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.card_giftcard,
                        size: 14,
                        color: Colors.purple,
                      ),
                      label: const Text('Lottery Scam'),
                      onPressed: () => _loadSample(
                        'Congratulations! You won Rs. 25,00,000. Send account details to claim.',
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.lock_clock,
                        size: 14,
                        color: Colors.red,
                      ),
                      label: const Text('Fake OTP'),
                      onPressed: () => _loadSample(
                        'Your card ending in 4128 has a pending charge. Share OTP to cancel.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Demo disclaimer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amberLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 20,
                        color: AppTheme.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Local Heuristic Engine',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.amber,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This analysis uses local heuristic rules only. No data is sent to external servers. Results are based on pattern matching, not live threat intelligence.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.amber.withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
