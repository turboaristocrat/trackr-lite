import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/movement_entry.dart';
import '../theme/app_theme.dart';
import 'station_autocomplete_field.dart';

class EditMovementDayDialog extends StatefulWidget {
  final MovementDayItem initialItem;

  const EditMovementDayDialog({super.key, required this.initialItem});

  static Future<MovementDayItem?> show(
    BuildContext context, {
    required MovementDayItem item,
  }) {
    return showDialog<MovementDayItem>(
      context: context,
      builder: (_) => EditMovementDayDialog(initialItem: item),
    );
  }

  @override
  State<EditMovementDayDialog> createState() => _EditMovementDayDialogState();
}

class _EditMovementDayDialogState extends State<EditMovementDayDialog> {
  late MovementItemType _type;
  late TextEditingController _stayStationCtrl;
  late TextEditingController _customTextCtrl;
  final List<_RunControllers> _runsCtrl = [];

  @override
  void initState() {
    super.initState();
    _type = widget.initialItem.type;
    _stayStationCtrl = TextEditingController(text: widget.initialItem.stayStation);
    _customTextCtrl = TextEditingController(text: widget.initialItem.customText);

    if (widget.initialItem.runs.isNotEmpty) {
      for (final r in widget.initialItem.runs) {
        _runsCtrl.add(_RunControllers(
          from: TextEditingController(text: r.fromStation),
          to: TextEditingController(text: r.toStation),
          dep: TextEditingController(text: r.departureTime),
          arr: TextEditingController(text: r.arrivalTime),
          isOvernight: r.isOvernight,
        ));
      }
    } else {
      _runsCtrl.add(_RunControllers(
        from: TextEditingController(),
        to: TextEditingController(),
        dep: TextEditingController(),
        arr: TextEditingController(),
        isOvernight: false,
      ));
    }
  }

  @override
  void dispose() {
    _stayStationCtrl.dispose();
    _customTextCtrl.dispose();
    for (final r in _runsCtrl) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRun() {
    setState(() {
      _runsCtrl.add(_RunControllers(
        from: TextEditingController(),
        to: TextEditingController(),
        dep: TextEditingController(),
        arr: TextEditingController(),
        isOvernight: false,
      ));
    });
  }

  void _removeRun(int index) {
    if (_runsCtrl.length > 1) {
      setState(() {
        final removed = _runsCtrl.removeAt(index);
        removed.dispose();
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    if (ctrl.text.contains(':')) {
      final parts = ctrl.text.split(':');
      final h = int.tryParse(parts[0]) ?? now.hour;
      final m = int.tryParse(parts[1]) ?? now.minute;
      initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      ctrl.text = '$hh:$mm';
    }
  }

  void _save() {
    final List<MovementRun> runs = [];
    if (_type == MovementItemType.transit) {
      for (final r in _runsCtrl) {
        final from = r.from.text.trim().toUpperCase();
        final to = r.to.text.trim().toUpperCase();
        final dep = r.dep.text.trim();
        final arr = r.arr.text.trim();
        if (from.isNotEmpty || to.isNotEmpty || dep.isNotEmpty || arr.isNotEmpty) {
          runs.add(MovementRun(
            fromStation: from,
            toStation: to,
            departureTime: dep,
            arrivalTime: arr,
            isOvernight: r.isOvernight,
          ));
        }
      }
    }

    final updated = MovementDayItem(
      date: widget.initialItem.date,
      type: _type,
      runs: runs,
      stayStation: _stayStationCtrl.text.trim().toUpperCase(),
      customText: _customTextCtrl.text.trim(),
      isManualOverride: true,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = widget.initialItem.date;
    try {
      final dt = DateTime.parse(widget.initialItem.date);
      dateLabel = DateFormat('EEE, dd MMM yyyy').format(dt);
    } catch (_) {}

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Day Movement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented type selector
              SegmentedButton<MovementItemType>(
                segments: const [
                  ButtonSegment(
                    value: MovementItemType.transit,
                    label: Text('Transit', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.train_rounded, size: 14),
                  ),
                  ButtonSegment(
                    value: MovementItemType.stay,
                    label: Text('Stay', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.home_work_rounded, size: 14),
                  ),
                  ButtonSegment(
                    value: MovementItemType.custom,
                    label: Text('Custom', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.note_alt_rounded, size: 14),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) => setState(() => _type = set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 16),

              // === Case 1: Stay ===
              if (_type == MovementItemType.stay) ...[
                StationAutocompleteField(
                  controller: _stayStationCtrl,
                  label: 'Stay / Stabled Station (Code)',
                  hintText: 'e.g. CGY, KTYM, AFK',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Outputs format: "DD.MM.YY :- Stay at [Station]"',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],

              // === Case 2: Custom ===
              if (_type == MovementItemType.custom) ...[
                TextField(
                  controller: _customTextCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Custom Movement Note',
                    hintText: 'e.g. Proceed to HQ, Machine under maintenance',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Outputs format: "DD.MM.YY :- [Your custom note]"',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],

              // === Case 3: Transit Run(s) ===
              if (_type == MovementItemType.transit) ...[
                for (int i = 0; i < _runsCtrl.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _runsCtrl.length > 1 ? 'Run #${i + 1}' : 'Transit Run',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                            ),
                            const Spacer(),
                            if (_runsCtrl.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.redDanger),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Remove this run',
                                onPressed: () => _removeRun(i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: StationAutocompleteField(
                                controller: _runsCtrl[i].from,
                                label: 'From',
                                hintText: 'e.g. KTYM',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StationAutocompleteField(
                                controller: _runsCtrl[i].to,
                                label: 'To',
                                hintText: 'e.g. CGY',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTime(_runsCtrl[i].dep),
                                child: IgnorePointer(
                                  child: TextFormField(
                                    controller: _runsCtrl[i].dep,
                                    decoration: const InputDecoration(
                                      labelText: 'Left / Dep',
                                      hintText: '09:16',
                                      prefixIcon: Icon(Icons.access_time_rounded, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTime(_runsCtrl[i].arr),
                                child: IgnorePointer(
                                  child: TextFormField(
                                    controller: _runsCtrl[i].arr,
                                    decoration: const InputDecoration(
                                      labelText: 'Arrived',
                                      hintText: '16:36',
                                      prefixIcon: Icon(Icons.access_time_filled_rounded, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Overnight run (spans into next morning)', style: TextStyle(fontSize: 12)),
                          value: _runsCtrl[i].isOvernight,
                          onChanged: (val) {
                            setState(() => _runsCtrl[i].isOvernight = val ?? false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primary,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Another Run on this Date', style: TextStyle(fontSize: 12.5)),
                  onPressed: _addRun,
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      actions: [
        if (widget.initialItem.isManualOverride)
          TextButton(
            onPressed: () {
              // Return a reset signal (customItem with isManualOverride = false)
              final reset = widget.initialItem.copyWith(isManualOverride: false);
              Navigator.pop(context, reset);
            },
            child: const Text('Reset to Auto', style: TextStyle(color: AppTheme.redDanger, fontSize: 12.5)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Entry'),
        ),
      ],
    );
  }
}

class _RunControllers {
  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController dep;
  final TextEditingController arr;
  bool isOvernight;

  _RunControllers({
    required this.from,
    required this.to,
    required this.dep,
    required this.arr,
    this.isOvernight = false,
  });

  void dispose() {
    from.dispose();
    to.dispose();
    dep.dispose();
    arr.dispose();
  }
}
