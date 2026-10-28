import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/components/status_chip.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  ScanType? _filterType;

  // Pre-populated demo scan history
  final List<ScanHistoryItem> _allHistory = [
    ScanHistoryItem(
      input: 'https://sbi-update-kyc.xyz/login',
      result: ScanResult(
        id: 'hist-1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        type: ScanType.link,
        riskLevel: RiskLevel.critical,
        title: 'High Risk URL — Phishing Detected',
        description: 'Analysis detected multiple red flags including untrusted .xyz TLD and typosquatting mimicking State Bank of India.',
        warnings: const [
          WarningIndicator(
            title: 'Unusual domain extension (.xyz)',
            description:
                'Commonly associated with low-cost disposable phishing sites.',
            icon: Icons.dns,
          ),
          WarningIndicator(
            title: 'Impersonation of Financial Institution',
            description: 'Contains "sbi" keyword without official sbi.co.in authorization.',
            icon: Icons.account_balance,
          ),
        ],
        recommendation: 'Do not click or enter bank credentials. Block this domain and report to cybercrime.gov.in.',
      ),
    ),
    ScanHistoryItem(
      input: 'URGENT: Your electricity power will be disconnected at 9:30 PM due to unpaid bill. Immediately call 9876543210.',
      result: ScanResult(
        id: 'hist-2',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: ScanType.sms,
        riskLevel: RiskLevel.high,
        title: 'Suspicious Utility Extortion SMS',
        description: 'Contains high-pressure deadline and personal mobile phone number disguised as power utility helpline.',
        warnings: const [
          WarningIndicator(
            title: 'Manufactured Urgency',
            description:
                'Sets immediate time limit to trigger panic and hasty payment.',
            icon: Icons.schedule,
          ),
          WarningIndicator(
            title: 'Personal Contact Number',
            description: 'Official electricity boards use registered shortcodes, not individual 10-digit mobile numbers.',
            icon: Icons.phone_android,
          ),
        ],
        recommendation: 'Do not call the phone number or make any payment. Verify outstanding dues exclusively via your state discom official portal.',
      ),
    ),
    ScanHistoryItem(
      input: 'https://www.onlinesbi.sbi',
      result: ScanResult(
        id: 'hist-3',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: ScanType.link,
        riskLevel: RiskLevel.safe,
        title: 'Legitimate Banking Portal',
        description: 'Verified top-level domain registered to official State Bank of India infrastructure.',
        warnings: const [],
        recommendation: 'URL passed verification. Remember to always verify the padlock icon in your browser address bar.',
      ),
    ),
    ScanHistoryItem(
      input: 'Dear user, Rs. 25,000 lottery won in Lucky Draw. Click http://bit.ly/claim-prize to receive payout in your bank.',
      result: ScanResult(
        id: 'hist-4',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: ScanType.sms,
        riskLevel: RiskLevel.critical,
        title: 'Advance-Fee Fraud Scam',
        description: 'Offers fictitious prize winnings requiring link navigation or advance fee payments.',
        warnings: const [
          WarningIndicator(
            title: 'Shortened URL (bit.ly)',
            description: 'Obfuscates actual final destination URL.',
            icon: Icons.link_off,
          ),
          WarningIndicator(
            title: 'Unsolicited Lottery / Financial Gain',
            description: 'Classic social engineering bait offering unrealistic financial windfalls.',
            icon: Icons.currency_rupee,
          ),
        ],
        recommendation: 'Never pay any processing fee or share bank details. Report sender to National Cyber Crime Reporting Portal (1930).',
      ),
    ),
  ];

  late List<ScanHistoryItem> _historyList;

  @override
  void initState() {
    super.initState();
    _historyList = List.from(_allHistory);
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Scan History?'),
        content: const Text(
          'This will remove all demo scan logs from your current session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              setState(() {
                _historyList.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterType == null
        ? _historyList
        : _historyList
              .where((item) => item.result.type == _filterType)
              .toList();

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Scan History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_historyList.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppTheme.navyText,
              ),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Activity'),
                  selected: _filterType == null,
                  onSelected: (_) => setState(() => _filterType = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Links'),
                  selected: _filterType == ScanType.link,
                  onSelected: (_) =>
                      setState(() => _filterType = ScanType.link),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('SMS'),
                  selected: _filterType == ScanType.sms,
                  onSelected: (_) => setState(() => _filterType = ScanType.sms),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Voice (0)'),
                  selected: _filterType == ScanType.voice,
                  onSelected: (_) =>
                      setState(() => _filterType = ScanType.voice),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // History List or Empty State
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.grayBorder),
                            ),
                            child: const Icon(
                              Icons.history_toggle_off,
                              size: 40,
                              color: AppTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Scans Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navyText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _historyList.isEmpty
                                ? 'Your scan history is empty. Analyze links or text messages to see results here.'
                                : 'No scan history matching this filter category.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScanResultScreen(
                                    result: item.result,
                                    scannedInput: item.input,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.indigo.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          item.result.type == ScanType.link
                                              ? Icons.link
                                              : item.result.type == ScanType.sms
                                              ? Icons.sms
                                              : Icons.mic,
                                          color: AppTheme.indigo,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.result.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.navyText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        riskLevel: item.result.riskLevel,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.input,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: AppTheme.navyLight,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatTimestamp(item.result.timestamp),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                      const Row(
                                        children: [
                                          Text(
                                            'View Details',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.indigo,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: AppTheme.indigo,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

class ScanHistoryItem {
  final String input;
  final ScanResult result;

  const ScanHistoryItem({required this.input, required this.result});
}
