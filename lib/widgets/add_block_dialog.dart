import 'package:flutter/material.dart';
import '../models/block_entry.dart';
import '../theme/app_theme.dart';
import 'station_autocomplete_field.dart';

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
      backgroundColor: AppTheme.cardBg,
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
  ];

  final List<String> _lineOptions = ['UP', 'DN', 'Both', 'SL', 'Yard'];

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
    if (!_lineOptions.contains(_line)) {
      _line = 'UP';
    }
    _unit = e?.outputUnit ?? (_isTransit ? 'Km' : 'Nos');

    // Try to match activity if editing
    if (e != null && !e.isTransit && e.activity.isNotEmpty) {
      final parts = e.activity.split(' ');
      if (parts.length >= 2) {
        final act = parts.last;
        final item = parts.sublist(0, parts.length - 1).join(' ');
        if (!_railItems.contains(item)) _railItems.add(item);
        if (!_railActions.contains(act)) _railActions.add(act);
        _selectedItem = item;
        _selectedAction = act;
      }
    }
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

  Future<void> _addCustomWorkItem() async {
    final ctrl = TextEditingController();
    final item = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Work Item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Work Item Name',
            hintText: 'e.g. Check Rails, Glued Joints',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );

    if (item != null && item.isNotEmpty) {
      setState(() {
        if (!_railItems.contains(item)) {
          _railItems.add(item);
        }
        _selectedItem = item;
        _updateActivityText();
      });
    }
  }

  Future<void> _addCustomAction() async {
    final ctrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Action'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Action Name',
            hintText: 'e.g. replaced, dismantled, shifted',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: const Text('Add Action'),
          ),
        ],
      ),
    );

    if (action != null && action.isNotEmpty) {
      setState(() {
        if (!_railActions.contains(action)) {
          _railActions.add(action);
        }
        _selectedAction = action;
        _updateActivityText();
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle & Header
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  _isTransit ? Icons.directions_railway_rounded : Icons.build_circle_rounded,
                  color: _isTransit ? AppTheme.amberAccent : AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.initialEntry != null
                      ? 'Edit Entry'
                      : (_isTransit ? 'Log Movement / Transit' : 'Log Track Block'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Block', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: true, label: Text('Transit', style: TextStyle(fontSize: 12))),
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
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
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

            // Station From and To with Station Name & Code while typing
            Row(
              children: [
                Expanded(
                  child: StationAutocompleteField(
                    controller: _fromCtrl,
                    label: 'From Station',
                    hintText: 'e.g. CGY',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 18),
                ),
                Expanded(
                  child: StationAutocompleteField(
                    controller: _toCtrl,
                    label: 'To Station',
                    hintText: 'e.g. CGV',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Track Line (Block only): UP, DN, Both, SL, Yard
            if (!_isTransit) ...[
              Row(
                children: [
                  const Text('Line: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: _lineOptions.map((l) {
                      final sel = _line == l;
                      return ChoiceChip(
                        label: Text(
                          l,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                            color: sel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        selected: sel,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.surfaceContainerLow,
                        onSelected: (_) => setState(() => _line = l),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Work Items Dropdown & Actions Dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Work Item Dropdown + Add Custom Option
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _railItems.contains(_selectedItem) ? _selectedItem : _railItems.first,
                      decoration: const InputDecoration(
                        labelText: 'Work Item',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                      ),
                      isExpanded: true,
                      items: [
                        ..._railItems.map(
                          (item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)),
                        ),
                        const DropdownMenuItem(
                          value: '__ADD_CUSTOM_ITEM__',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Text('+ Custom Item...', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == '__ADD_CUSTOM_ITEM__') {
                          _addCustomWorkItem();
                        } else if (val != null) {
                          setState(() {
                            _selectedItem = val;
                            _updateActivityText();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Action Dropdown + Add Custom Action
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _railActions.contains(_selectedAction) ? _selectedAction : _railActions.first,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        prefixIcon: Icon(Icons.bolt_outlined, size: 18),
                      ),
                      isExpanded: true,
                      items: [
                        ..._railActions.map(
                          (action) => DropdownMenuItem(value: action, child: Text(action, overflow: TextOverflow.ellipsis)),
                        ),
                        const DropdownMenuItem(
                          value: '__ADD_CUSTOM_ACTION__',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Text('+ Custom...', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == '__ADD_CUSTOM_ACTION__') {
                          _addCustomAction();
                        } else if (val != null) {
                          setState(() {
                            _selectedAction = val;
                            _updateActivityText();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Activity Field (Editable text preview)
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

            // Remarks field (Custom remarks without predefined pills)
            TextField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                hintText: 'e.g. Km 84/10 to 86/00, caution order, etc.',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 18),

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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
