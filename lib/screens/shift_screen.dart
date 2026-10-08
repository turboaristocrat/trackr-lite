import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/block_entry.dart';
import '../models/shift_log.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_block_dialog.dart';
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
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.surface,
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
        backgroundColor: AppTheme.surface,
        title: const Text('Complete & Archive Shift?'),
        content: const Text(
          'This will save today\'s shift into History and share the report to WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete & Share'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted && _shift != null) {
      await WhatsAppService.shareToWhatsApp(_shift!);
      await StorageService.completeAndArchiveShift(_shift!);
      widget.onShiftCompleted();
      await _loadShift();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift archived to History successfully!'),
            backgroundColor: AppTheme.primary,
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
      displayDate = DateFormat('EEE, dd MMM yyyy').format(dt);
    } catch (_) {
      displayDate = shift.date;
    }

    return Column(
      children: [
        // Top Header Card (Machine, Section, Date)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Date Chip (tappable)
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
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
                  const Spacer(),
                  // Edit Setup Button
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.textSecondary),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit Machine / Section',
                    onPressed: _editSetup,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Machine & Section Pills
              InkWell(
                onTap: _editSetup,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.train_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${shift.machineType} ${shift.machineNo}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            '${shift.division} / ${shift.section}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondary),
                          ),
                        ],
                      ),
                    ),
                    if (shift.stabledStation.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '🏠 ${shift.stabledStation}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Quick KPI Stats Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildKpi('${shift.blockCount}', 'Blocks', Icons.layers_rounded, AppTheme.primary),
                    Container(width: 1, height: 20, color: AppTheme.outline.withValues(alpha: 0.3)),
                    _buildKpi(
                      shift.totalBlockOutput > 0
                          ? (shift.totalBlockOutput.truncateToDouble() == shift.totalBlockOutput
                              ? shift.totalBlockOutput.toInt().toString()
                              : shift.totalBlockOutput.toStringAsFixed(1))
                          : '0',
                      'Output',
                      Icons.trending_up_rounded,
                      AppTheme.secondary,
                    ),
                    Container(width: 1, height: 20, color: AppTheme.outline.withValues(alpha: 0.3)),
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

        // Action Buttons (+ Log Block / + Transit)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addOrEditBlock(isTransit: false),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Log Track Block'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.amberAccent,
                    side: const BorderSide(color: AppTheme.amberAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _addOrEditBlock(isTransit: true),
                  icon: const Icon(Icons.directions_railway_rounded, size: 18),
                  label: const Text('Log Transit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        // Blocks List
        Expanded(
          child: shift.blocks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: shift.blocks.length,
                  itemBuilder: (ctx, i) {
                    final block = shift.blocks[i];
                    return _buildBlockCard(block, i + 1);
                  },
                ),
        ),

        // Bottom WhatsApp Share Bar
        _buildBottomShareBar(shift),
      ],
    );
  }

  Widget _buildKpi(String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
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
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_calendar_rounded, size: 36, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'No blocks logged today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Log Track Block" to record your first block, or "+ Log Transit" for movement runs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(BlockEntry b, int number) {
    final isTransit = b.isTransit;
    final color = isTransit ? AppTheme.amberAccent : AppTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: number badge, Line, and Edit/Delete
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    isTransit ? '#$number TRANSIT' : '#$number ${b.line} LINE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${b.startTime} - ${b.endTime}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
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
            // Route & Output
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.trip_origin_rounded, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        b.stationFrom,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textSecondary),
                      ),
                      Text(
                        b.stationTo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Output Highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isTransit
                        ? '${b.output} Km'
                        : '${b.output.toStringAsFixed(b.output.truncateToDouble() == b.output ? 0 : 2)} ${b.outputUnit}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  ),
                ),
              ],
            ),
            if (b.remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outline.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Copy button
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.surfaceVariant,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copy Report Text',
              onPressed: () async {
                await WhatsAppService.copyToClipboard(shift);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift report copied to clipboard!')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            // Big WhatsApp Share Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share WhatsApp Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => WhatsAppService.shareToWhatsApp(shift),
              ),
            ),
            const SizedBox(width: 8),
            // Save & Archive
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.archive_outlined, size: 20),
              tooltip: 'Complete & Archive Shift',
              onPressed: _completeShift,
            ),
          ],
        ),
      ),
    );
  }
}
