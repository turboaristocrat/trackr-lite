import 'package:flutter/material.dart';
import '../models/shift_log.dart';
import '../services/station_service.dart';
import '../theme/app_theme.dart';

class EditShiftDialog extends StatefulWidget {
  final ShiftLog currentShift;

  const EditShiftDialog({super.key, required this.currentShift});

  static Future<ShiftLog?> show(BuildContext context, ShiftLog current) {
    return showDialog<ShiftLog>(
      context: context,
      builder: (_) => EditShiftDialog(currentShift: current),
    );
  }

  @override
  State<EditShiftDialog> createState() => _EditShiftDialogState();
}

class _EditShiftDialogState extends State<EditShiftDialog> {
  late String _machineType;
  late TextEditingController _machineNoCtrl;
  late String _division;
  late TextEditingController _sectionCtrl;
  late TextEditingController _readyStationCtrl;
  late TextEditingController _readyTimeCtrl;
  late TextEditingController _stabledStationCtrl;

  final List<String> _machineTypes = [
    'UTV',
    'CSM',
    'DUOMAT',
    '09-3X',
    'BCM',
    'UNIMAT',
    'DGS',
    'MPT',
    'RGM',
    'T-28',
    'SBCM',
  ];

  final List<String> _divisions = ['TVC', 'PGT', 'MAS', 'SA', 'MDU', 'TPJ'];

  @override
  void initState() {
    super.initState();
    _machineType = widget.currentShift.machineType;
    _machineNoCtrl = TextEditingController(text: widget.currentShift.machineNo);
    _division = widget.currentShift.division;
    _sectionCtrl = TextEditingController(text: widget.currentShift.section);
    _readyStationCtrl = TextEditingController(text: widget.currentShift.readyStation);
    _readyTimeCtrl = TextEditingController(text: widget.currentShift.readyTime);
    _stabledStationCtrl = TextEditingController(text: widget.currentShift.stabledStation);
  }

  @override
  void dispose() {
    _machineNoCtrl.dispose();
    _sectionCtrl.dispose();
    _readyStationCtrl.dispose();
    _readyTimeCtrl.dispose();
    _stabledStationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReadyTime() async {
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
      setState(() => _readyTimeCtrl.text = '$h:$m');
    }
  }

  void _save() {
    final updated = widget.currentShift.copyWith(
      machineType: _machineType,
      machineNo: _machineNoCtrl.text.trim(),
      division: _division,
      section: _sectionCtrl.text.trim().toUpperCase(),
      readyStation: _readyStationCtrl.text.trim().toUpperCase(),
      readyTime: _readyTimeCtrl.text.trim(),
      stabledStation: _stabledStationCtrl.text.trim().toUpperCase(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 8),
          Text('Shift Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set your machine & section once—TRACKR Lite remembers it automatically.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Machine Type & Number (e.g. UTV 005H)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _machineTypes.contains(_machineType) ? _machineType : _machineTypes.first,
                    decoration: const InputDecoration(labelText: 'Machine Type'),
                    items: _machineTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _machineType = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _machineNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Machine No',
                      hintText: 'e.g. 005H',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Division & Section
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _divisions.contains(_division) ? _division : _divisions.first,
                    decoration: const InputDecoration(labelText: 'Division'),
                    items: _divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _division = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _sectionCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Section Code',
                      hintText: 'e.g. KTYM',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Machine Ready Line (Station & Time)
            const Text('Machine Ready:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _readyStationCtrl.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const [];
                      return StationService.search(textEditingValue.text).map((s) => s.code);
                    },
                    onSelected: (selection) => _readyStationCtrl.text = selection,
                    fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                      _readyStationCtrl = ctrl;
                      return TextField(
                        controller: ctrl,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Ready At Station',
                          hintText: 'e.g. CGY',
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _pickReadyTime,
                    borderRadius: BorderRadius.circular(10),
                    child: IgnorePointer(
                      child: TextField(
                        controller: _readyTimeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ready Time',
                          hintText: '09:25',
                          prefixIcon: Icon(Icons.access_time_rounded, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Machine Stabled Line (Station)
            const Text('Machine Stabled:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _stabledStationCtrl.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const [];
                return StationService.search(textEditingValue.text).map((s) => s.code);
              },
              onSelected: (selection) => _stabledStationCtrl.text = selection,
              fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                _stabledStationCtrl = ctrl;
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Stabled Station',
                    hintText: 'e.g. KTYM',
                    prefixIcon: Icon(Icons.home_work_outlined, size: 18),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Setup'),
        ),
      ],
    );
  }
}
