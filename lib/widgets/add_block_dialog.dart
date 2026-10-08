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
  late TextEditingController _activityCtrl;
  late TextEditingController _outputCtrl;
  late TextEditingController _remarksCtrl;

  String _line = 'UP';
  String _unit = 'Nos';
  String _selectedAction = 'unloaded';
  String _selectedItem = 'Sleepers';

  final List<String> _railItems = [
    'Sleepers',
    'P&C Sleepers',
    'Channel Sleepers',
    'SEJ Sleepers',
    'Rails',
    'Crossing',
    'OHE Mast',
  ];

  final List<String> _railActions = [
    'unloaded',
    'loaded',
    'packed',
    'erected',
    'renewed',
  ];

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
    _activityCtrl = TextEditingController(text: e?.activity ?? 'Sleepers unloaded');
    _outputCtrl = TextEditingController(
      text: e != null && e.output > 0
          ? (e.output.truncateToDouble() == e.output ? e.output.toInt().toString() : e.output.toString())
          : '',
    );
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _line = e?.line ?? 'UP';
    _unit = e?.outputUnit ?? (_isTransit ? 'Km' : 'Nos');
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _activityCtrl.dispose();
    _outputCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _updateActivityText() {
    setState(() {
      _activityCtrl.text = '$_selectedItem $_selectedAction';
    });
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
      activity: _isTransit ? 'Transit Run' : _activityCtrl.text.trim(),
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
                      : (_isTransit ? 'Log Movement / Transit' : 'Log Track Block'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Block', style: TextStyle(fontSize: 11.5))),
                    ButtonSegment(value: true, label: Text('Transit', style: TextStyle(fontSize: 11.5))),
                  ],
                  selected: {_isTransit},
                  onSelectionChanged: (set) {
                    setState(() {
                      _isTransit = set.first;
                      _unit = _isTransit ? 'Km' : 'Nos';
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Time Row (BT: Start - End hrs)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(_startCtrl),
                    borderRadius: BorderRadius.circular(10),
                    child: IgnorePointer(
                      child: TextField(
                        controller: _startCtrl,
                        decoration: InputDecoration(
                          labelText: _isTransit ? 'Start Time' : 'BT Start Time',
                          prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
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
                        decoration: InputDecoration(
                          labelText: _isTransit ? 'End Time' : 'BT End Time',
                          prefixIcon: const Icon(Icons.access_time_filled_rounded, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Station From and To
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _fromCtrl.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const [];
                      return StationService.search(textEditingValue.text).map((s) => s.code);
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
                          hintText: 'e.g. CGY',
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
                      return StationService.search(textEditingValue.text).map((s) => s.code);
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
                          hintText: 'e.g. CGV',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Track Line (Block only)
            if (!_isTransit) ...[
              Row(
                children: [
                  const Text('Line: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
              const SizedBox(height: 14),

              // Item Chips (Rails, Sleepers, P&C Sleepers, etc.)
              const Text('Work Item:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _railItems.map((item) {
                    final sel = _selectedItem == item;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(item, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                        selected: sel,
                        selectedColor: AppTheme.secondary.withValues(alpha: 0.25),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedItem = item;
                              _updateActivityText();
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Action Chips (unloaded, loaded, packed, etc.)
              Row(
                children: [
                  const Text('Action: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Wrap(
                    spacing: 6,
                    children: _railActions.map((action) {
                      final sel = _selectedAction == action;
                      return ChoiceChip(
                        label: Text(action, style: TextStyle(fontSize: 11.5, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                        selected: sel,
                        selectedColor: AppTheme.amberAccent.withValues(alpha: 0.25),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedAction = action;
                              _updateActivityText();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Activity Field (editable text)
              TextField(
                controller: _activityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Report Activity Label',
                  hintText: 'e.g. Sleepers unloaded',
                  prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Quantity / Output
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _outputCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isTransit ? 'Transit Distance' : 'Quantity / Output',
                      hintText: _isTransit ? 'e.g. 18.5' : 'e.g. 16',
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
                        DropdownMenuItem(value: 'Nos', child: Text('Nos')),
                        DropdownMenuItem(value: 'Sleepers', child: Text('Sleepers')),
                        DropdownMenuItem(value: 'Km', child: Text('Km')),
                        DropdownMenuItem(value: 'Sets', child: Text('Sets')),
                        DropdownMenuItem(value: 'Meters', child: Text('Meters')),
                        DropdownMenuItem(value: 'Hoppers', child: Text('Hoppers')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _unit = val);
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('Km', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Optional Remarks
            TextField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks / Extra info (optional)',
                hintText: 'e.g. Km 84/10 to 86/00',
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                widget.initialEntry != null ? 'Update Entry' : 'Add to Shift Log',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
