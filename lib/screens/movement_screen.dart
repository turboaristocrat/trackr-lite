import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/movement_entry.dart';
import '../services/movement_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_movement_day_dialog.dart';

class MovementScreen extends StatefulWidget {
  const MovementScreen({super.key});

  @override
  State<MovementScreen> createState() => MovementScreenState();
}

class MovementScreenState extends State<MovementScreen> {
  DateTime _selectedMonth = DateTime.now();
  final MovementFormatStyle _style = MovementFormatStyle.register;
  bool _isLoading = true;
  List<MovementDayItem> _days = [];
  String _machineName = 'UTV005H';
  String _division = 'TVC';

  @override
  void initState() {
    super.initState();
    refreshMovement();
  }

  Future<void> refreshMovement() async {
    setState(() => _isLoading = true);

    final history = await StorageService.getHistory();
    final active = await StorageService.getActiveShift();
    final overrides = await StorageService.getMovementOverrides();
    final machine = await StorageService.getMachineName();
    final div = await StorageService.getDivision();

    final generated = MovementService.generateMonthDays(
      year: _selectedMonth.year,
      month: _selectedMonth.month,
      historyShifts: history,
      activeShift: active,
      overrides: overrides,
    );

    if (mounted) {
      setState(() {
        _days = generated;
        _machineName = machine.isNotEmpty ? machine : 'UTV005H';
        _division = div.isNotEmpty ? div : 'TVC';
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    refreshMovement();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    refreshMovement();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select Month',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      refreshMovement();
    }
  }

  Future<void> _editDay(MovementDayItem item) async {
    final updated = await EditMovementDayDialog.show(context, item: item);
    if (updated != null) {
      if (!updated.isManualOverride) {
        // Was reset to auto
        await StorageService.deleteMovementOverride(updated.date);
      } else {
        await StorageService.saveMovementOverride(updated);
      }
      await refreshMovement();
    }
  }

  String _getReportText() {
    return MovementService.formatMovementReport(
      monthDays: _days,
      selectedMonth: _selectedMonth,
      machineName: _machineName,
      division: _division,
      style: _style,
    );
  }

  void _showReportDialog() {
    final reportText = _getReportText();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            const Icon(Icons.alt_route_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Movement – ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              reportText,
              style: const TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.45,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            onPressed: () async {
              await MovementService.copyToClipboard(reportText);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied movement summary to clipboard')),
                );
              }
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Machine Movement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              '$_machineName • $_division',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: refreshMovement,
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview Full Text',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month selector & Style switcher card
                _buildHeaderControls(monthLabel),

                // Day entries list
                Expanded(
                  child: _days.isEmpty
                      ? const Center(
                          child: Text(
                            'No movement entries for this month.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _days.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _days[index];
                            return _buildDayCard(item);
                          },
                        ),
                ),

                // Bottom Share Action Bar
                _buildShareBottomBar(),
              ],
            ),
    );
  }

  Widget _buildHeaderControls(String monthLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          // Month navigation row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _previousMonth,
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _nextMonth,
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(MovementDayItem item) {
    final parsedDate = DateTime.tryParse(item.date) ?? DateTime.now();
    final dayNum = DateFormat('dd').format(parsedDate);
    final dayName = DateFormat('E').format(parsedDate);
    final isWeekend = parsedDate.weekday == DateTime.sunday;

    return InkWell(
      onTap: () => _editDay(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isManualOverride
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.borderColor,
            width: item.isManualOverride ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date Badge
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isWeekend
                    ? AppTheme.redDanger.withValues(alpha: 0.12)
                    : AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isWeekend ? AppTheme.redDanger : AppTheme.primary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    dayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isWeekend ? AppTheme.redDanger : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: _buildItemDetails(item),
            ),

            // Manual Override Pill or Edit Icon
            if (item.isManualOverride)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'EDITED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),

            const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetails(MovementDayItem item) {
    if (item.type == MovementItemType.stay) {
      final st = item.stayStation.trim().toUpperCase();
      if (st.isEmpty) {
        return const Text(
          '—',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        );
      }

      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bed_rounded, size: 13, color: Colors.amber),
                const SizedBox(width: 5),
                Text(
                  'Stay at $st',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (item.type == MovementItemType.custom) {
      return Text(
        item.customText.isNotEmpty ? item.customText : '(Custom Note)',
        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    // Transit runs
    if (item.runs.isEmpty) {
      return const Text(
        'No runs logged',
        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: item.runs.map((run) {
        final from = run.fromStation.isNotEmpty ? run.fromStation : '_____';
        final to = run.toStation.isNotEmpty ? run.toStation : '_____';
        final dep = run.departureTime.isNotEmpty ? MovementService.formatTimeDot(run.departureTime) : '_____';
        final arr = run.arrivalTime.isNotEmpty ? MovementService.formatTimeDot(run.arrivalTime) : '_____';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(
                '$from – $to',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '($dep – $arr hrs)',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShareBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // WhatsApp Share Button
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.whatsAppGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () async {
                  final text = _getReportText();
                  await MovementService.shareToWhatsApp(text);
                },
              ),
            ),
            const SizedBox(width: 8),

            // Telegram Share Button
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Telegram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () async {
                  final text = _getReportText();
                  final title = 'Machine Movement – ${DateFormat('MMMM yyyy').format(_selectedMonth)}';
                  await MovementService.shareToTelegram(text, title);
                },
              ),
            ),
            const SizedBox(width: 8),

            // Copy Button
            IconButton.filledTonal(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copy Text',
              onPressed: () async {
                final text = _getReportText();
                await MovementService.copyToClipboard(text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied movement summary to clipboard')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
