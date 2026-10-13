import 'package:flutter/material.dart';
import '../models/block_entry.dart';
import '../models/shift_log.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_block_dialog.dart';
import '../widgets/edit_machine_ready_dialog.dart';
import '../widgets/edit_machine_stabled_dialog.dart';
import '../widgets/edit_shift_dialog.dart';
import '../widgets/edit_shift_remarks_dialog.dart';
import '../widgets/select_date_shift_dialog.dart';

class ShiftScreen extends StatefulWidget {
  final VoidCallback onShiftCompleted;

  const ShiftScreen({super.key, required this.onShiftCompleted});

  @override
  State<ShiftScreen> createState() => ShiftScreenState();
}

class ShiftScreenState extends State<ShiftScreen> {
  ShiftLog? _shift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshShift();
  }

  Future<void> refreshShift() async {
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

    // Auto-save & cross-check to history datewise if shift has any logged activity
    final hasData = updated.blocks.isNotEmpty ||
        updated.remarks.trim().isNotEmpty ||
        updated.stabledStation.trim().isNotEmpty;
    if (hasData) {
      await StorageService.saveOrUpdateHistoryShift(updated);
      widget.onShiftCompleted();
    }
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
      final time = res['time'] as String;
      bool isNight = _shift!.isNightShift;
      if (time.isNotEmpty && time.contains(':')) {
        final hour = int.tryParse(time.split(':')[0]) ?? 12;
        if (hour >= 18 || hour < 6) {
          isNight = true;
        }
      }
      await _saveShift(_shift!.copyWith(
        readyStation: res['station'],
        readyTime: time,
        isNightShift: isNight,
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

  Future<void> _editShiftRemarks() async {
    if (_shift == null) return;
    final res = await EditShiftRemarksDialog.show(
      context,
      initialRemarks: _shift!.remarks,
    );
    if (res != null) {
      await _saveShift(_shift!.copyWith(
        remarks: res,
      ));
    }
  }

  Future<void> _pickDate() async {
    if (_shift == null) return;
    final res = await SelectDateShiftDialog.show(
      context,
      initialDate: _shift!.date,
      initialIsNightShift: _shift!.isNightShift,
      initialTime: _shift!.readyTime,
    );

    if (res != null) {
      final date = res['date'] as String;
      final isNight = res['isNightShift'] as bool;
      final time = res['time'] as String;

      // Cross-check & auto-save current shift to history if user changes date or night shift
      final currentHasData = _shift!.blocks.isNotEmpty ||
          _shift!.remarks.trim().isNotEmpty ||
          _shift!.stabledStation.trim().isNotEmpty;
      if (currentHasData && (_shift!.date != date || _shift!.isNightShift != isNight)) {
        await StorageService.saveOrUpdateHistoryShift(_shift!);
        widget.onShiftCompleted();
      }

      // If a shift already exists in history for the selected date, load it!
      final existingForDate = await StorageService.getHistoryShiftForDate(date, isNightShift: isNight);
      if (existingForDate != null) {
        await _saveShift(existingForDate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded saved shift for $date from History'),
              backgroundColor: AppTheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _saveShift(_shift!.copyWith(
          date: date,
          isNightShift: isNight,
          readyTime: time.isNotEmpty ? time : _shift!.readyTime,
        ));
      }
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
            onPressed: () async {
              Navigator.pop(ctx);
              if (_shift != null) {
                // Cross-check & auto-save to history datewise
                await StorageService.saveOrUpdateHistoryShift(_shift!);
                widget.onShiftCompleted();
                await ReportService.shareToTelegram(_shift!);
              }
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

    final result = await StorageService.saveOrUpdateHistoryShift(_shift!);
    widget.onShiftCompleted();

    if (mounted) {
      switch (result) {
        case SaveHistoryResult.savedNew:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift saved to History successfully!'),
              backgroundColor: AppTheme.railSafetyGreen,
              duration: Duration(seconds: 2),
            ),
          );
          break;
        case SaveHistoryResult.updated:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('History updated with latest shift changes!'),
              backgroundColor: AppTheme.railSafetyGreen,
              duration: Duration(seconds: 2),
            ),
          );
          break;
        case SaveHistoryResult.noChanges:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift is already saved with no changes.'),
              backgroundColor: AppTheme.secondary,
              duration: Duration(seconds: 2),
            ),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _shift == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final shift = _shift!;
    final displayDate = shift.formattedDate;

    int blockCounter = 1;

    return Column(
      children: [
        // ================= TOP HEADER CARD =================
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Date Chip + Day/Night Toggle on left, Report Button on right (Never overflows)
              Row(
                children: [
                  // Date Chip
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: shift.isNightShift
                            ? const Color(0xFF6750A4).withValues(alpha: 0.1)
                            : AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: shift.isNightShift
                              ? const Color(0xFF6750A4).withValues(alpha: 0.35)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            shift.isNightShift ? Icons.nightlight_round : Icons.calendar_today_rounded,
                            size: 14,
                            color: shift.isNightShift ? const Color(0xFF6750A4) : AppTheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            displayDate,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: shift.isNightShift ? const Color(0xFF6750A4) : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Day / Night Quick Toggle Pill
                  InkWell(
                    onTap: () => _saveShift(shift.copyWith(isNightShift: !shift.isNightShift)),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: shift.isNightShift
                            ? const Color(0xFF6750A4).withValues(alpha: 0.12)
                            : const Color(0xFFFDB324).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: shift.isNightShift
                              ? const Color(0xFF6750A4).withValues(alpha: 0.35)
                              : const Color(0xFFD69400).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            shift.isNightShift ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                            size: 13,
                            color: shift.isNightShift ? const Color(0xFF6750A4) : const Color(0xFF996800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shift.isNightShift ? 'Night' : 'Day',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: shift.isNightShift ? const Color(0xFF6750A4) : const Color(0xFF996800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Big Report Button (Full visibility)
                  InkWell(
                    onTap: _previewReport,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, size: 15, color: AppTheme.primary),
                          SizedBox(width: 5),
                          Text(
                            'Report',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Machine Badge + Division / Section Badge
              Row(
                children: [
                  // Machine Badge
                  InkWell(
                    onTap: _editSetup,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.train_rounded, size: 15, color: AppTheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            shift.machineName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Division & Section Chip
                  Expanded(
                    child: InkWell(
                      onTap: _editSetup,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                shift.section.isNotEmpty
                                    ? '${shift.division} / ${shift.section}'
                                    : 'Division: ${shift.division}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(
                              'Edit ➔',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // KPI bar (Spacious and breathable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildKpi('${shift.blockCount}', 'Blocks', Icons.layers_rounded, AppTheme.primary),
                    Container(width: 1, height: 22, color: AppTheme.borderColor),
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
                    Container(width: 1, height: 22, color: AppTheme.borderColor),
                    _buildKpi(
                      shift.totalTransitKm > 0
                          ? (shift.totalTransitKm.truncateToDouble() == shift.totalTransitKm
                              ? '${shift.totalTransitKm.toInt()} Km'
                              : '${shift.totalTransitKm.toStringAsFixed(1)} Km')
                          : '0 Km',
                      'Movement',
                      Icons.navigation_rounded,
                      AppTheme.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ================= DEDICATED MACHINE READY SECTION =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: _editMachineReady,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: shift.readyStation.isNotEmpty ? AppTheme.railSafetyGreen.withValues(alpha: 0.35) : AppTheme.borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.railSafetyGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.railSafetyGreen, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shift.readyStation.isNotEmpty && shift.readyTime.isNotEmpty
                          ? 'Machine ready at ${shift.readyStation} – ${shift.readyTime} hrs.'
                          : (shift.readyStation.isNotEmpty
                              ? 'Machine ready at ${shift.readyStation}'
                              : 'Machine Ready: Tap to set station & time'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

        // Single Unified Action Button (+ Log Block / Transit) - Full Width Railway Yellow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB324), // Railway Signal Yellow / Amber
                foregroundColor: const Color(0xFF191C20), // High-contrast dark typography
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: const Color(0xFFD69400).withValues(alpha: 0.5), width: 1),
                ),
              ),
              onPressed: () => _addOrEditBlock(isTransit: false),
              icon: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF191C20)),
              label: const Text(
                'Add Block / Movement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  letterSpacing: 0.3,
                  color: Color(0xFF191C20),
                ),
              ),
            ),
          ),
        ),

        // Blocks List + Remarks + Machine Stabled at the bottom
        Expanded(
          child: shift.blocks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 56),
                  itemCount: shift.blocks.length + 2,
                  itemBuilder: (ctx, i) {
                    if (i == shift.blocks.length) {
                      // ================= DEDICATED MACHINE STABLED SECTION =================
                      return _buildMachineStabledCard(shift);
                    }
                    if (i == shift.blocks.length + 1) {
                      // ================= DEDICATED SHIFT REMARKS SECTION =================
                      return _buildRemarksCard(shift);
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

  Widget _buildRemarksCard(ShiftLog shift) {
    final hasRemarks = shift.remarks.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: InkWell(
        onTap: _editShiftRemarks,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasRemarks ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasRemarks
                      ? 'Remarks: ${shift.remarks.trim()}'
                      : 'Shift Remarks: Tap to add shift notes / remarks',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: hasRemarks ? AppTheme.textPrimary : AppTheme.textMuted,
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

  Widget _buildMachineStabledCard(ShiftLog shift) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      child: InkWell(
        onTap: _editMachineStabled,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: shift.stabledStation.isNotEmpty ? AppTheme.amberAccent.withValues(alpha: 0.5) : AppTheme.borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.amberAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_circle_outlined, color: AppTheme.amberAccent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shift.stabledStation.isNotEmpty
                      ? (shift.stabledTime.isNotEmpty
                          ? 'Machine stabled at ${shift.stabledStation} – ${shift.stabledTime} hrs.'
                          : 'Machine stabled at ${shift.stabledStation}.')
                      : 'Machine Stabled: Tap to set station at end of shift',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              const SizedBox(height: 1),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 56.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_calendar_rounded, size: 28, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No blocks logged today',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap "+ Add Block / Movement" above to record Sleepers/Rails work or movement runs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_shift != null) ...[
            _buildMachineStabledCard(_shift!),
            _buildRemarksCard(_shift!),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockCard(BlockEntry b, int blockNumber) {
    final isTransit = b.isTransit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Line: Tag, Section & Line, Action Icons
            Row(
              children: [
                // Block tag pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isTransit ? AppTheme.amberAccent.withValues(alpha: 0.12) : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTransit ? AppTheme.amberAccent.withValues(alpha: 0.35) : AppTheme.borderColor,
                    ),
                  ),
                  child: Text(
                    isTransit ? 'MOVEMENT' : 'Block – $blockNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.3,
                      color: isTransit ? AppTheme.secondary : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Block Time Range
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        isTransit ? '${b.startTime} – ${b.endTime}' : 'BT: ${b.startTime} – ${b.endTime}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Edit & Delete Buttons
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17, color: AppTheme.textMuted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit block',
                  onPressed: () => _addOrEditBlock(existing: b),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppTheme.textMuted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete block',
                  onPressed: () => _deleteBlock(b.id),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle: Section Station from - to and Line
            Row(
              children: [
                const Icon(Icons.train_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isTransit
                        ? '${b.stationFrom}  ➔  ${b.stationTo}'
                        : '${b.stationFrom}  ➔  ${b.stationTo}   •   ${b.line} Line',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Work items / Activities
            if (isTransit) ...[
              if (b.output > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.amberAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.amberAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Movement Distance: ${b.output} Km',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.secondary),
                  ),
                ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: b.items.map((item) {
                  final outStr = item.output.truncateToDouble() == item.output
                      ? item.output.toInt().toString()
                      : item.output.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        children: [
                          TextSpan(
                            text: '${item.activity}: ',
                            style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                          ),
                          TextSpan(
                            text: '$outStr ${item.outputUnit}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Remarks line
            if (b.remarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.notes_rounded, size: 14, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.remarks,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomShareBar(ShiftLog shift) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // WhatsApp Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.whatsAppGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 17),
                label: const Text(
                  'WhatsApp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  // Cross-check for changes and auto-save to history datewise
                  SaveHistoryResult? result;
                  if (shift.blocks.isNotEmpty || shift.remarks.isNotEmpty || shift.stabledStation.isNotEmpty) {
                    result = await StorageService.saveOrUpdateHistoryShift(shift);
                    widget.onShiftCompleted();
                  }
                  await ReportService.shareToWhatsApp(shift);
                  if (mounted && result != null && result != SaveHistoryResult.noChanges) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result == SaveHistoryResult.updated
                            ? 'Opening WhatsApp (History updated with latest changes)'
                            : 'Opening WhatsApp (Shift auto-saved to History)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // Telegram Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 17),
                label: const Text(
                  'Telegram',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  // Cross-check for changes and auto-save to history datewise
                  SaveHistoryResult? result;
                  if (shift.blocks.isNotEmpty || shift.remarks.isNotEmpty || shift.stabledStation.isNotEmpty) {
                    result = await StorageService.saveOrUpdateHistoryShift(shift);
                    widget.onShiftCompleted();
                  }
                  await ReportService.shareToTelegram(shift);
                  if (mounted) {
                    String msg = 'Opening Telegram (Report also copied to clipboard)';
                    if (result == SaveHistoryResult.updated) {
                      msg = 'Opening Telegram (History updated with latest changes)';
                    } else if (result == SaveHistoryResult.savedNew) {
                      msg = 'Opening Telegram (Shift auto-saved to History)';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // Copy Report Button
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerLow,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy Report Text',
              onPressed: () async {
                if (shift.blocks.isNotEmpty || shift.remarks.isNotEmpty || shift.stabledStation.isNotEmpty) {
                  await StorageService.saveOrUpdateHistoryShift(shift);
                  widget.onShiftCompleted();
                }
                await ReportService.copyToClipboard(shift);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift report copied & saved to History!')),
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
              icon: const Icon(Icons.archive_outlined, size: 19),
              tooltip: 'Save to History',
              onPressed: _completeShift,
            ),
          ],
        ),
      ),
    );
  }
}
