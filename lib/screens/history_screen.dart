import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shift_log.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<ShiftLog> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshHistory();
  }

  Future<void> refreshHistory() async {
    setState(() => _isLoading = true);
    final list = await StorageService.getHistory();
    if (mounted) {
      setState(() {
        _history = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteShift(String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Shift Log?'),
        content: Text('Are you sure you want to delete the log for $date? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteHistoryItem(date);
      await refreshHistory();
    }
  }

  void _showReportDialog(ShiftLog log) {
    final text = ReportService.formatReport(log);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            const Icon(Icons.description_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text('Report: ${log.date}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', height: 1.4),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied report to clipboard')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppTheme.whatsAppGreen),
            tooltip: 'WhatsApp',
            onPressed: () => ReportService.shareToWhatsApp(log),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.telegramBlue),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('Telegram', style: TextStyle(color: Colors.white)),
            onPressed: () => ReportService.shareToTelegram(log),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    final json = await StorageService.exportBackupJson();
    // ignore: deprecated_member_use
    await Share.share(json, subject: 'TRACKR_Lite_Backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json');
  }

  Future<void> _importBackup() async {
    final ctrl = TextEditingController();
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Import Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste raw JSON backup below to restore your shift history:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{\n  "app": "TRACKR_Lite", ...\n}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await StorageService.importBackupJson(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );

    if (success == true) {
      await refreshHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!'), backgroundColor: AppTheme.railSafetyGreen),
        );
      }
    } else if (success == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to parse backup JSON'), backgroundColor: AppTheme.redDanger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Shift History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 20),
            tooltip: 'Export Backup',
            onPressed: _exportBackup,
          ),
          IconButton(
            icon: const Icon(Icons.upload_rounded, size: 20),
            tooltip: 'Import Backup',
            onPressed: _importBackup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final log = _history[i];
                    return _buildHistoryCard(log);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 42, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            const Text(
              'No past shifts recorded yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'When you tap "Complete & Archive Shift" on the Active Shift screen, your log will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ShiftLog log) {
    String displayDate;
    try {
      final dt = DateTime.parse(log.date);
      displayDate = DateFormat('EEE, dd MMM yyyy').format(dt);
    } catch (_) {
      displayDate = log.date;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReportDialog(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      displayDate,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    log.machineName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13.5),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.telegramBlue),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Share to Telegram',
                    onPressed: () => ReportService.shareToTelegram(log),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppTheme.whatsAppGreen),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Share to WhatsApp',
                    onPressed: () => ReportService.shareToWhatsApp(log),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.redDanger),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete Log',
                    onPressed: () => _deleteShift(log.date),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Metrics Row
              Row(
                children: [
                  _buildMetricPill('${log.blockCount} Blocks', AppTheme.primary),
                  if (log.totalBlockOutput > 0) ...[
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      '${log.totalBlockOutput.toStringAsFixed(log.totalBlockOutput.truncateToDouble() == log.totalBlockOutput ? 0 : 2)} Out',
                      AppTheme.secondary,
                    ),
                  ],
                  if (log.totalTransitKm > 0) ...[
                    const SizedBox(width: 8),
                    _buildMetricPill('${log.totalTransitKm} Km Run', AppTheme.amberAccent),
                  ],
                  const Spacer(),
                  const Text('Tap to view ➔', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
