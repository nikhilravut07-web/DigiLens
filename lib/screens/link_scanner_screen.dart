import 'package:flutter/material.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/screens/qr_scanner_screen.dart';
import 'package:digilens/theme/app_theme.dart';

class LinkScannerScreen extends StatefulWidget {
  const LinkScannerScreen({super.key});

  @override
  State<LinkScannerScreen> createState() => _LinkScannerScreenState();
}

class _LinkScannerScreenState extends State<LinkScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _performScan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = _urlController.text.trim();
      final result = await UrlAnalysisService.analyzeUrl(url);

      // Record to history
      ScanHistoryService.instance.recordScan(rawInput: url, result: result);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ScanResultScreen(result: result, scannedInput: url),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL analysis error: $e'),
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

  void _loadSample(String sampleUrl) {
    setState(() {
      _urlController.text = sampleUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Link Scanner',
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
                    color: AppTheme.indigoLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.indigoLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.indigoLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: AppTheme.indigo,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phishing & Suspicious URL Guard',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navyText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check links for typosquatting, hidden redirects, and known phishing patterns.',
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
                ),
                const SizedBox(height: 24),

                // Input field
                Text('Enter URL to analyze', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Paste or type a full URL, including http:// or https://',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _performScan(),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/login',
                    hintStyle: const TextStyle(color: AppTheme.mutedText),
                    prefixIcon: const Icon(
                      Icons.language,
                      color: AppTheme.navyLight,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                      tooltip: 'Scan QR Code',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                        );
                      },
                    ),
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
                      return 'Please enter a URL';
                    }
                    final trimmed = value.trim();
                    if (!trimmed.startsWith('http://') &&
                        !trimmed.startsWith('https://')) {
                      _urlController.text = 'https://$trimmed';
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
                      backgroundColor: AppTheme.indigo,
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
                      _isLoading ? 'Analyzing URL…' : 'Scan Link Now',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sample links
                Text(
                  'Try sample links (DEMO)',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: Colors.amber,
                      ),
                      label: const Text('Suspicious Bank'),
                      onPressed: () =>
                          _loadSample('https://sbi-update-kyc.xyz/login'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.link_off,
                        size: 14,
                        color: Colors.red,
                      ),
                      label: const Text('IP Address'),
                      onPressed: () =>
                          _loadSample('http://192.168.1.50/secure-verify'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      label: const Text('Trusted Gov'),
                      onPressed: () => _loadSample('https://www.india.gov.in'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.code,
                        size: 14,
                        color: Colors.purple,
                      ),
                      label: const Text('Shortened'),
                      onPressed: () =>
                          _loadSample('https://bit.ly/suspicious-bank'),
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
                              'This analysis uses local heuristic rules and pattern matching only. No data is sent to external servers. For real threat-intelligence verification, a backend API integration is required.',
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
