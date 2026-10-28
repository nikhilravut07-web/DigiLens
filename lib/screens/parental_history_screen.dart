import 'package:flutter/material.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/components/parental_pin_modal.dart';
import 'package:digilens/theme/app_theme.dart';

/// Screen displaying parental activity history and logs.
class ParentalHistoryScreen extends StatefulWidget {
  const ParentalHistoryScreen({super.key});

  @override
  State<ParentalHistoryScreen> createState() => _ParentalHistoryScreenState();
}

class _ParentalHistoryScreenState extends State<ParentalHistoryScreen> {
  List<ParentalActivityRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = ParentalControlService.instance.history;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'cancelled':
        return Colors.orange;
      case 'blocked':
        case 'failed':
        return AppTheme.red;
      default:
        return AppTheme.indigo;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'blocked':
        return Icons.block_outlined;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _confirmClearHistory() async {
    final verified = await ParentalPinModal.show(
      context,
      title: 'Authorize Clear History',
      subtitle: 'Enter your 6-digit PIN to clear parental activity history.',
    );

    if (!verified || !mounted) return;

    await ParentalControlService.instance.clearHistory();
    _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parental activity history cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Parental Activity History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.red),
              tooltip: 'Clear History',
              onPressed: _confirmClearHistory,
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.indigo.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history, size: 48, color: AppTheme.indigo),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Activity Recorded Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Website approvals, blocks, and PIN attempts\nwill appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final record = _history[index];
                final statusColor = _getStatusColor(record.status);
                final statusIcon = _getStatusIcon(record.status);
                final dt = record.timestamp.toLocal();
                final timeStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.grayBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record.eventType.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.details,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navyText,
                          height: 1.3,
                        ),
                      ),
                      if (record.targetUrl != null && record.targetUrl!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lavenderBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.targetUrl!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.indigo,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
