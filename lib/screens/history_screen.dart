import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shift_log.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final ValueChanged<ShiftLog>? onSelectShift;

  const HistoryScreen({super.key, this.onSelectShift});

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

  Future<void> _deleteShift(String date, {bool? isNightShift}) async {
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
      await StorageService.deleteHistoryItem(date, isNightShift: isNightShift);
      await refreshHistory();
    }
  }

  void _showHistoryActionSheet(ShiftLog log) {
    String displayDate;
    if (log.isNightShift) {
      displayDate = '${log.formattedDate} (Night)';
    } else {
      try {
        final dt = DateTime.parse(log.date);
        displayDate = DateFormat('EEE, dd MMM yyyy').format(dt);
      } catch (_) {
        displayDate = log.date;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayDate,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${log.machineName} • ${log.division} • ${log.blockCount} Blocks',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.onSelectShift != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 20),
                  ),
                  title: const Text('Edit in Active Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Load this shift to active editor to add or modify blocks', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await StorageService.saveActiveShift(log);
                    widget.onSelectShift?.call(log);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.telegramBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: AppTheme.telegramBlue, size: 20),
                ),
                title: const Text('Share to Telegram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  ReportService.shareToTelegram(log);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.whatsAppGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.whatsAppGreen, size: 20),
                ),
                title: const Text('Share to WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  ReportService.shareToWhatsApp(log);
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.redDanger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppTheme.redDanger, size: 20),
                ),
                title: const Text('Delete Shift Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.redDanger)),
                subtitle: const Text('Permanently remove this shift from history', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteShift(log.date, isNightShift: log.isNightShift);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          if (widget.onSelectShift != null)
            TextButton.icon(
              icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primary),
              label: const Text('Edit in Active Shift', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                await StorageService.saveActiveShift(log);
                widget.onSelectShift?.call(log);
              },
            ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.redDanger),
            label: const Text('Delete', style: TextStyle(color: AppTheme.redDanger, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteShift(log.date, isNightShift: log.isNightShift);
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
              'Your shifts are automatically saved here datewise as you log blocks or share reports.',
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
    if (log.isNightShift) {
      displayDate = '${log.formattedDate} (Night)';
    } else {
      try {
        final dt = DateTime.parse(log.date);
        displayDate = DateFormat('EEE, dd MMM yyyy').format(dt);
      } catch (_) {
        displayDate = log.date;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReportDialog(log),
        onLongPress: () => _showHistoryActionSheet(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 440;

              final actionsWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onSelectShift != null)
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      color: AppTheme.primary,
                      tooltip: 'Edit in Active Shift',
                      onTap: () async {
                        await StorageService.saveActiveShift(log);
                        widget.onSelectShift?.call(log);
                      },
                    ),
                  _buildActionButton(
                    icon: Icons.send_rounded,
                    color: AppTheme.telegramBlue,
                    tooltip: 'Share to Telegram',
                    onTap: () => ReportService.shareToTelegram(log),
                  ),
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppTheme.whatsAppGreen,
                    tooltip: 'Share to WhatsApp',
                    onTap: () => ReportService.shareToWhatsApp(log),
                  ),
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.redDanger,
                    tooltip: 'Delete Log',
                    onTap: () => _deleteShift(log.date, isNightShift: log.isNightShift),
                  ),
                ],
              );

              final metricsWidget = Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildMetricPill('${log.blockCount} Blocks', AppTheme.primary),
                  if (log.totalBlockOutput > 0)
                    _buildMetricPill(
                      '${log.totalBlockOutput.toStringAsFixed(log.totalBlockOutput.truncateToDouble() == log.totalBlockOutput ? 0 : 2)} Out',
                      AppTheme.secondary,
                    ),
                  if (log.totalTransitKm > 0)
                    _buildMetricPill('${log.totalTransitKm} Km Run', AppTheme.amberAccent),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        Expanded(
                          child: Text(
                            log.machineName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text('Hold for menu ➔', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    metricsWidget,
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        actionsWidget,
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      actionsWidget,
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      metricsWidget,
                      const Spacer(),
                      const Text('Tap to view ➔', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
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
