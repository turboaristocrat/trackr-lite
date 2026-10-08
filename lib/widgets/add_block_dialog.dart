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

class _WorkItemFormItem {
  String selectedItem;
  String selectedAction;
  TextEditingController activityCtrl;
  TextEditingController outputCtrl;
  String unit;

  _WorkItemFormItem({
    this.selectedItem = 'Sleepers',
    this.selectedAction = 'unloaded',
    String? activity,
    String output = '',
    this.unit = 'Nos',
  })  : activityCtrl = TextEditingController(text: activity ?? 'Sleepers unloaded'),
        outputCtrl = TextEditingController(text: output);

  void dispose() {
    activityCtrl.dispose();
    outputCtrl.dispose();
  }

  void updateActivity() {
    activityCtrl.text = '$selectedItem $selectedAction';
  }
}

class _AddBlockDialogState extends State<AddBlockDialog> {
  late bool _isTransit;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  late TextEditingController _transitDistanceCtrl;
  late TextEditingController _remarksCtrl;

  String _line = 'UP';
  final List<_WorkItemFormItem> _workItems = [];

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
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _line = e?.line ?? 'UP';
    if (!_lineOptions.contains(_line)) {
      _line = 'UP';
    }

    _transitDistanceCtrl = TextEditingController(
      text: e != null && e.isTransit && e.output > 0
          ? (e.output.truncateToDouble() == e.output ? e.output.toInt().toString() : e.output.toString())
          : '',
    );

    // Populate work items
    if (e != null && !e.isTransit && e.items.isNotEmpty) {
      for (final item in e.items) {
        final formItem = _createFormItemFromWorkItem(item);
        _workItems.add(formItem);
      }
    } else {
      _workItems.add(_WorkItemFormItem());
    }
  }

  _WorkItemFormItem _createFormItemFromWorkItem(WorkItem item) {
    String selItem = 'Sleepers';
    String selAction = 'unloaded';

    final parts = item.activity.split(' ');
    if (parts.length >= 2) {
      final act = parts.last;
      final itm = parts.sublist(0, parts.length - 1).join(' ');
      if (!_railItems.contains(itm)) _railItems.add(itm);
      if (!_railActions.contains(act)) _railActions.add(act);
      selItem = itm;
      selAction = act;
    }

    final outStr = item.output > 0
        ? (item.output.truncateToDouble() == item.output ? item.output.toInt().toString() : item.output.toString())
        : '';

    return _WorkItemFormItem(
      selectedItem: selItem,
      selectedAction: selAction,
      activity: item.activity,
      output: outStr,
      unit: item.outputUnit.isNotEmpty ? item.outputUnit : 'Nos',
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _transitDistanceCtrl.dispose();
    _remarksCtrl.dispose();
    for (final w in _workItems) {
      w.dispose();
    }
    super.dispose();
  }

  void _addNewWorkItem() {
    setState(() {
      _workItems.add(_WorkItemFormItem());
    });
  }

  void _removeWorkItem(int index) {
    if (_workItems.length <= 1) return;
    setState(() {
      final removed = _workItems.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _addCustomWorkItem(_WorkItemFormItem target) async {
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
        target.selectedItem = item;
        target.updateActivity();
      });
    }
  }

  Future<void> _addCustomAction(_WorkItemFormItem target) async {
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
        target.selectedAction = action;
        target.updateActivity();
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

    final List<WorkItem> builtItems = [];
    if (_isTransit) {
      final dist = double.tryParse(_transitDistanceCtrl.text.trim()) ?? 0.0;
      builtItems.add(WorkItem(
        activity: 'Transit Run',
        output: dist,
        outputUnit: 'Km',
      ));
    } else {
      for (final w in _workItems) {
        final outVal = double.tryParse(w.outputCtrl.text.trim()) ?? 0.0;
        final act = w.activityCtrl.text.trim().isNotEmpty
            ? w.activityCtrl.text.trim()
            : '${w.selectedItem} ${w.selectedAction}';
        builtItems.add(WorkItem(
          activity: act,
          output: outVal,
          outputUnit: w.unit,
        ));
      }
    }

    final entry = BlockEntry(
      id: widget.initialEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _startCtrl.text.trim(),
      endTime: _endCtrl.text.trim(),
      stationFrom: from,
      stationTo: to,
      line: _isTransit ? 'Transit' : _line,
      items: builtItems,
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
              const SizedBox(height: 14),

              // ================= WORK ITEMS LIST =================
              ...List.generate(_workItems.length, (index) {
                final itemForm = _workItems[index];
                return _buildWorkItemCard(itemForm, index);
              }),

              // "+ Add Another Work Item" button
              OutlinedButton.icon(
                onPressed: _addNewWorkItem,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primary),
                label: const Text(
                  '+ Add Another Work Item',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              // Transit Distance
              TextField(
                controller: _transitDistanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Transit Distance (Km)',
                  hintText: 'e.g. 18.5',
                  prefixIcon: Icon(Icons.speed_rounded, size: 18),
                  suffixText: 'Km',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Remarks field
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

  Widget _buildWorkItemCard(_WorkItemFormItem formItem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Work Item #${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primary),
                ),
              ),
              const Spacer(),
              if (_workItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.redDanger),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove Item',
                  onPressed: () => _removeWorkItem(index),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Work Item Dropdown & Action Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Work Item Dropdown
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _railItems.contains(formItem.selectedItem) ? formItem.selectedItem : _railItems.first,
                  decoration: const InputDecoration(
                    labelText: 'Work Item',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 17),
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
                      _addCustomWorkItem(formItem);
                    } else if (val != null) {
                      setState(() {
                        formItem.selectedItem = val;
                        formItem.updateActivity();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Action Dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _railActions.contains(formItem.selectedAction) ? formItem.selectedAction : _railActions.first,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    prefixIcon: Icon(Icons.bolt_outlined, size: 17),
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
                      _addCustomAction(formItem);
                    } else if (val != null) {
                      setState(() {
                        formItem.selectedAction = val;
                        formItem.updateActivity();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity & Unit
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: formItem.outputCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'e.g. 16',
                    prefixIcon: Icon(Icons.numbers_rounded, size: 17),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: formItem.unit,
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
                    if (val != null) setState(() => formItem.unit = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Activity Label preview
          TextField(
            controller: formItem.activityCtrl,
            decoration: const InputDecoration(
              labelText: 'Report Label',
              hintText: 'e.g. Sleepers unloaded',
              prefixIcon: Icon(Icons.label_outline_rounded, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}
