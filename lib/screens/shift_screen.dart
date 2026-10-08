import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/block_entry.dart';
import '../models/shift_log.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_block_dialog.dart';
import '../widgets/edit_machine_ready_dialog.dart';
import '../widgets/edit_machine_stabled_dialog.dart';
import '../widgets/edit_shift_dialog.dart';

class ShiftScreen extends StatefulWidget {
  final VoidCallback onShiftCompleted;

  const ShiftScreen({super.key, required this.onShiftCompleted});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  ShiftLog? _shift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShift();
  }

  Future<void> _loadShift() async {
    setState(() => _isLoading = true);
    final shift = await StorageService.getActiveShift();
    if (mounted) {
      setState(() {
        _shift = shift;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveShift(ShiftLog updated) async {
    setState(() => _shift = updated);
    await StorageService.saveActiveShift(updated);
  }

  Future<void> _addOrEditBlock({BlockEntry? existing, bool isTransit = false}) async {
    final result = await AddBlockDialog.show(
      context,
      initialEntry: existing,
      defaultIsTransit: isTransit,
    );

    if (result != null && _shift != null) {
      final blocks = List<BlockEntry>.from(_shift!.blocks);
      if (existing != null) {
        final idx = blocks.indexWhere((b) => b.id == existing.id);
        if (idx != -1) blocks[idx] = result;
      } else {
        blocks.add(result);
      }
      await _saveShift(_shift!.copyWith(blocks: blocks));
    }
  }

  Future<void> _deleteBlock(String id) async {
    if (_shift == null) return;
    final blocks = List<BlockEntry>.from(_shift!.blocks)..removeWhere((b) => b.id == id);
    await _saveShift(_shift!.copyWith(blocks: blocks));
  }

  Future<void> _editSetup() async {
    if (_shift == null) return;
    final updated = await EditShiftDialog.show(context, _shift!);
    if (updated != null) {
      await _saveShift(updated);
    }
  }

  Future<void> _editMachineReady() async {
    if (_shift == null) return;
    final res = await EditMachineReadyDialog.show(
      context,
      initialStation: _shift!.readyStation,
      initialTime: _shift!.readyTime,
    );
    if (res != null) {
      await _saveShift(_shift!.copyWith(
        readyStation: res['station'],
        readyTime: res['time'],
      ));
    }
  }

  Future<void> _editMachineStabled() async {
    if (_shift == null) return;
    final res = await EditMachineStabledDialog.show(
      context,
      initialStation: _shift!.stabledStation,
      initialTime: _shift!.stabledTime,
    );
    if (res != null) {
      await _saveShift(_shift!.copyWith(
        stabledStation: res['station'],
        stabledTime: res['time'],
      ));
    }
  }

  Future<void> _pickDate() async {
    if (_shift == null) return;
    DateTime current;
    try {
      current = DateTime.parse(_shift!.date);
    } catch (_) {
      current = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            surface: AppTheme.cardBg,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      await _saveShift(_shift!.copyWith(date: dateStr));
    }
  }

  void _previewReport() {
    if (_shift == null) return;
    final text = ReportService.formatReport(_shift!);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Row(
          children: [
            Icon(Icons.preview_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Report Preview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.telegramBlue),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Telegram'),
            onPressed: () {
              Navigator.pop(ctx);
              ReportService.shareToTelegram(_shift!);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _completeShift() async {
    if (_shift == null || _shift!.blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one block before saving shift')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Complete & Archive Shift?'),
        content: const Text(
          'This will save today\'s shift into History and share the official report to Telegram.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.telegramBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete & Share'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted && _shift != null) {
      await ReportService.shareToTelegram(_shift!);
      await StorageService.completeAndArchiveShift(_shift!);
      widget.onShiftCompleted();
      await _loadShift();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift archived to History successfully!'),
            backgroundColor: AppTheme.railSafetyGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _shift == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final shift = _shift!;
    String displayDate;
    try {
      final dt = DateTime.parse(shift.date);
      displayDate = DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      displayDate = shift.date;
    }

    int blockCounter = 1;

    return Column(
      children: [
        // ================= TOP HEADER CARD =================
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Date Chip
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Machine Badge
                  InkWell(
                    onTap: _editSetup,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.train_rounded, size: 15, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            shift.machineName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.preview_rounded, size: 20, color: AppTheme.secondary),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Preview Report',
                    onPressed: _previewReport,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.textSecondary),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit Setup',
                    onPressed: _editSetup,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Division & Section
              InkWell(
                onTap: _editSetup,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Text(
                        '📍 Division: ${shift.division}   •   Section: ${shift.section}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      const Text(
                        'Edit ➔',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // KPI bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildKpi('${shift.blockCount}', 'Blocks', Icons.layers_rounded, AppTheme.primary),
                    Container(width: 1, height: 18, color: AppTheme.borderColor),
                    _buildKpi(
                      shift.totalBlockOutput > 0
                          ? (shift.totalBlockOutput.truncateToDouble() == shift.totalBlockOutput
                              ? shift.totalBlockOutput.toInt().toString()
                              : shift.totalBlockOutput.toStringAsFixed(0))
                          : '0',
                      'Total Output',
                      Icons.trending_up_rounded,
                      AppTheme.secondary,
                    ),
                    Container(width: 1, height: 18, color: AppTheme.borderColor),
                    _buildKpi(
                      shift.totalTransitKm > 0 ? '${shift.totalTransitKm}k' : '0k',
                      'Transit',
                      Icons.navigation_rounded,
                      AppTheme.amberAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ================= DEDICATED MACHINE READY SECTION =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: InkWell(
            onTap: _editMachineReady,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: shift.readyStation.isNotEmpty ? AppTheme.railSafetyGreen.withValues(alpha: 0.5) : AppTheme.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.railSafetyGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.railSafetyGreen, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shift.readyStation.isNotEmpty && shift.readyTime.isNotEmpty
                          ? 'Machine ready at ${shift.readyStation} – ${shift.readyTime} hrs.'
                          : (shift.readyStation.isNotEmpty
                              ? 'Machine ready at ${shift.readyStation}'
                              : 'Machine Ready: Tap to set station & time'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: shift.readyStation.isNotEmpty ? AppTheme.textPrimary : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ),

        // Action Buttons (+ Log Block / + Transit)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addOrEditBlock(isTransit: false),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Log Block'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addOrEditBlock(isTransit: true),
                  icon: const Icon(Icons.directions_railway_rounded, size: 18, color: AppTheme.secondary),
                  label: const Text('Log Transit'),
                ),
              ),
            ],
          ),
        ),

        // Blocks List + Machine Stabled at the bottom
        Expanded(
          child: shift.blocks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  itemCount: shift.blocks.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == shift.blocks.length) {
                      // ================= DEDICATED MACHINE STABLED SECTION =================
                      return _buildMachineStabledCard(shift);
                    }
                    final block = shift.blocks[i];
                    final currentIdx = block.isTransit ? 0 : blockCounter++;
                    return _buildBlockCard(block, currentIdx);
                  },
                ),
        ),

        // Bottom Primary Telegram Share Bar
        _buildBottomShareBar(shift),
      ],
    );
  }

  Widget _buildMachineStabledCard(ShiftLog shift) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      child: InkWell(
        onTap: _editMachineStabled,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: shift.stabledStation.isNotEmpty ? AppTheme.amberAccent.withValues(alpha: 0.6) : AppTheme.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.amberAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_circle_outlined, color: AppTheme.amberAccent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shift.stabledStation.isNotEmpty
                      ? (shift.stabledTime.isNotEmpty
                          ? 'Machine stabled at ${shift.stabledStation} – ${shift.stabledTime} hrs.'
                          : 'Machine stabled at ${shift.stabledStation}.')
                      : 'Machine Stabled: Tap to set station at end of shift',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: shift.stabledStation.isNotEmpty ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpi(String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_calendar_rounded, size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'No blocks logged today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Log Block" to record Sleepers/Rails work, or "+ Log Transit" for movement runs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(BlockEntry b, int blockNumber) {
    final isTransit = b.isTransit;
    final color = isTransit ? AppTheme.secondary : AppTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Block Number or Transit, Time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTransit ? AppTheme.amberAccent.withValues(alpha: 0.15) : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTransit ? AppTheme.amberAccent.withValues(alpha: 0.4) : AppTheme.borderColor,
                    ),
                  ),
                  child: Text(
                    isTransit ? 'TRANSIT' : 'Block – $blockNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: isTransit ? AppTheme.amberAccent : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isTransit
                      ? '${b.startTime} – ${b.endTime} hrs'
                      : 'BT: ${b.startTime} – ${b.endTime} hrs',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addOrEditBlock(existing: b),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.redDanger),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteBlock(b.id),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Section & Line
            Text(
              isTransit
                  ? '${b.stationFrom} – ${b.stationTo}'
                  : '${b.stationFrom} – ${b.stationTo} (${b.line})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),

            // Output items chips/pills
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: isTransit
                  ? [
                      if (b.output > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'Run: ${b.output} Km',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color),
                          ),
                        ),
                    ]
                  : b.items.map((item) {
                      final outStr = item.output.truncateToDouble() == item.output
                          ? item.output.toInt().toString()
                          : item.output.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${item.activity}: $outStr ${item.outputUnit}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color),
                        ),
                      );
                    }).toList(),
            ),

            if (b.remarks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Remarks: ${b.remarks}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomShareBar(ShiftLog shift) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Primary Telegram Button
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Share to Telegram',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () => ReportService.shareToTelegram(shift),
              ),
            ),
            const SizedBox(width: 8),

            // Secondary WhatsApp Button
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.whatsAppGreen.withValues(alpha: 0.15),
                foregroundColor: AppTheme.whatsAppGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              tooltip: 'Share via WhatsApp',
              onPressed: () => ReportService.shareToWhatsApp(shift),
            ),
            const SizedBox(width: 6),

            // Copy Report Button
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerLow,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.copy_rounded, size: 19),
              tooltip: 'Copy Report Text',
              onPressed: () async {
                await ReportService.copyToClipboard(shift);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift report copied to clipboard!')),
                  );
                }
              },
            ),
            const SizedBox(width: 6),

            // Complete & Archive Button
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.archive_outlined, size: 20),
              tooltip: 'Archive Shift to History',
              onPressed: _completeShift,
            ),
          ],
        ),
      ),
    );
  }
}
