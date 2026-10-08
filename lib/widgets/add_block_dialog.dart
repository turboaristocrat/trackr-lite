import 'package:flutter/material.dart';
import '../models/block_entry.dart';
import '../services/station_service.dart';
import '../theme/app_theme.dart';

class AddBlockDialog extends StatefulWidget {
  final BlockEntry? initialEntry;
  final bool defaultIsTransit;

  const AddBlockDialog({
    super.key,
    this.initialEntry,
    this.defaultIsTransit = false,
  });

  static Future<BlockEntry?> show(
    BuildContext context, {
    BlockEntry? initialEntry,
    bool defaultIsTransit = false,
  }) {
    return showModalBottomSheet<BlockEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddBlockDialog(
        initialEntry: initialEntry,
        defaultIsTransit: defaultIsTransit,
      ),
    );
  }

  @override
  State<AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<AddBlockDialog> {
  late bool _isTransit;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  late TextEditingController _outputCtrl;
  late TextEditingController _remarksCtrl;

  String _line = 'DN';
  String _unit = 'Sleepers';

  final List<String> _quickRemarks = [
    'Tamping done',
    'Caution order',
    'Traffic burst',
    'Point packing',
    'No traffic delay',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _isTransit = e?.isTransit ?? widget.defaultIsTransit;

    final now = TimeOfDay.now();
    final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _startCtrl = TextEditingController(text: e?.startTime ?? nowStr);
    _endCtrl = TextEditingController(text: e?.endTime ?? '');
    _fromCtrl = TextEditingController(text: e?.stationFrom ?? '');
    _toCtrl = TextEditingController(text: e?.stationTo ?? '');
    _outputCtrl = TextEditingController(
      text: e != null && e.output > 0 ? (e.output.truncateToDouble() == e.output ? e.output.toInt().toString() : e.output.toString()) : '',
    );
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _line = e?.line ?? 'DN';
    _unit = e?.outputUnit ?? (_isTransit ? 'Km' : 'Sleepers');
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _outputCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => ctrl.text = '$h:$m');
    }
  }

  void _save() {
    final from = _fromCtrl.text.trim().toUpperCase();
    final to = _toCtrl.text.trim().toUpperCase();

    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter From and To stations')),
      );
      return;
    }

    final outputVal = double.tryParse(_outputCtrl.text.trim()) ?? 0.0;

    final entry = BlockEntry(
      id: widget.initialEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _startCtrl.text.trim(),
      endTime: _endCtrl.text.trim(),
      stationFrom: from,
      stationTo: to,
      line: _isTransit ? 'Transit' : _line,
      output: outputVal,
      outputUnit: _isTransit ? 'Km' : _unit,
      remarks: _remarksCtrl.text.trim(),
      isTransit: _isTransit,
    );

    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle & Title
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  _isTransit ? Icons.directions_railway_rounded : Icons.build_circle_rounded,
                  color: _isTransit ? AppTheme.amberAccent : AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.initialEntry != null
                      ? 'Edit Entry'
                      : (_isTransit ? 'Log Transit Run' : 'Log Track Block'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Toggle Block vs Transit
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Block', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: true, label: Text('Transit', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_isTransit},
                  onSelectionChanged: (set) {
                    setState(() {
                      _isTransit = set.first;
                      _unit = _isTransit ? 'Km' : 'Sleepers';
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(_startCtrl),
                    borderRadius: BorderRadius.circular(10),
                    child: IgnorePointer(
                      child: TextField(
                        controller: _startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Start Time (24h)',
                          prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(_endCtrl),
                    borderRadius: BorderRadius.circular(10),
                    child: IgnorePointer(
                      child: TextField(
                        controller: _endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'End Time (24h)',
                          prefixIcon: Icon(Icons.access_time_filled_rounded, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Station From and To with autocomplete
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _fromCtrl.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const [];
                      return StationService.search(textEditingValue.text)
                          .map((s) => s.code);
                    },
                    onSelected: (selection) => _fromCtrl.text = selection,
                    fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                      _fromCtrl = ctrl;
                      return TextField(
                        controller: ctrl,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'From Station',
                          hintText: 'e.g. HAD',
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 18),
                ),
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _toCtrl.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const [];
                      return StationService.search(textEditingValue.text)
                          .map((s) => s.code);
                    },
                    onSelected: (selection) => _toCtrl.text = selection,
                    fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                      _toCtrl = ctrl;
                      return TextField(
                        controller: ctrl,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'To Station',
                          hintText: 'e.g. CGY',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Line selector (for block only)
            if (!_isTransit) ...[
              Row(
                children: [
                  const Text('Track Line: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: ['UP', 'DN', 'SL', 'Yard'].map((l) {
                      final sel = _line == l;
                      return ChoiceChip(
                        label: Text(l, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                        selected: sel,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                        onSelected: (_) => setState(() => _line = l),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Output row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _outputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isTransit ? 'Distance Run' : 'Block Output',
                      hintText: _isTransit ? 'e.g. 15.5' : 'e.g. 1250',
                      prefixIcon: Icon(_isTransit ? Icons.speed_rounded : Icons.numbers_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (!_isTransit)
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(value: 'Sleepers', child: Text('Sleepers')),
                        DropdownMenuItem(value: 'Km', child: Text('Km')),
                        DropdownMenuItem(value: 'Turnouts', child: Text('Turnouts')),
                        DropdownMenuItem(value: 'Meters', child: Text('Meters')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _unit = val);
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Km', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Remarks
            TextField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks / Work details (optional)',
                hintText: 'e.g. Tamping from Km 84/10 to 86/00',
              ),
            ),
            const SizedBox(height: 8),

            // Quick remark chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickRemarks.map((rem) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(rem, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.surfaceVariant.withValues(alpha: 0.4),
                      onPressed: () {
                        if (_remarksCtrl.text.isEmpty) {
                          _remarksCtrl.text = rem;
                        } else {
                          _remarksCtrl.text = '${_remarksCtrl.text}, $rem';
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton.icon(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTransit ? AppTheme.amberAccent : AppTheme.primary,
                foregroundColor: _isTransit ? Colors.black : Colors.white,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                widget.initialEntry != null ? 'Update Entry' : 'Add to Shift',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
