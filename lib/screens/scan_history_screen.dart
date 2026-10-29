import 'package:flutter/material.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/scan_history_service.dart';
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

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear Scan History?'),
        content: const Text(
          'This will delete all locally recorded scan results. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: AppTheme.white,
            ),
            onPressed: () {
              ScanHistoryService.instance.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan history cleared.')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Scan History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder<List<ScanHistoryItem>>(
            valueListenable: ScanHistoryService.instance.historyNotifier,
            builder: (context, items, _) {
              if (items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline, size: 22),
                tooltip: 'Clear history',
                onPressed: _confirmClearHistory,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Types', null),
                  const SizedBox(width: 8),
                  _buildFilterChip('Links', ScanType.link),
                  const SizedBox(width: 8),
                  _buildFilterChip('SMS Messages', ScanType.sms),
                  const SizedBox(width: 8),
                  _buildFilterChip('Voice Calls', ScanType.voice),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.grayBorder),

          // Main Content List
          Expanded(
            child: ValueListenableBuilder<List<ScanHistoryItem>>(
              valueListenable: ScanHistoryService.instance.historyNotifier,
              builder: (context, allItems, _) {
                final filtered = _filterType == null
                    ? allItems
                    : allItems.where((item) => item.result.type == _filterType).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildHistoryCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ScanType? type) {
    final isSelected = _filterType == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primary : AppTheme.navyText,
      ),
      backgroundColor: AppTheme.grayBackground,
      selectedColor: AppTheme.primaryLight.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.grayBorder,
          width: 1,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _filterType = type;
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.grayBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: const Icon(
                Icons.manage_search,
                size: 40,
                color: AppTheme.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Scan History Recorded',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filterType == null
                  ? 'Perform a scan using Link Scanner, SMS Analyzer, or incoming SMS guard to view verified results here.'
                  : 'No ${_filterType!.name.toUpperCase()} scans found. Try selecting "All Types".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, ScanHistoryItem item) {
    final IconData typeIcon;
    switch (item.result.type) {
      case ScanType.link:
        typeIcon = Icons.link;
        break;
      case ScanType.sms:
        typeIcon = Icons.sms_outlined;
        break;
      case ScanType.voice:
        typeIcon = Icons.phone_outlined;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.grayBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(typeIcon, size: 22, color: AppTheme.primary),
        ),
        title: Row(
          children: [
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
            StatusChip(riskLevel: item.result.riskLevel, compact: true),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.sanitizedInput,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.navyLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDate(item.result.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                  ),
                ),
                if (item.source != null && item.source!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.source!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
