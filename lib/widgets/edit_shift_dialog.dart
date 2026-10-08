import 'package:flutter/material.dart';
import '../models/shift_log.dart';
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
  late TextEditingController _stabledCtrl;

  final List<String> _machineTypes = [
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
    _stabledCtrl = TextEditingController(text: widget.currentShift.stabledStation);
  }

  @override
  void dispose() {
    _machineNoCtrl.dispose();
    _sectionCtrl.dispose();
    _stabledCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.currentShift.copyWith(
      machineType: _machineType,
      machineNo: _machineNoCtrl.text.trim(),
      division: _division,
      section: _sectionCtrl.text.trim().toUpperCase(),
      stabledStation: _stabledCtrl.text.trim().toUpperCase(),
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

            // Machine Type & Number
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
                  flex: 2,
                  child: TextField(
                    controller: _machineNoCtrl,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Machine No',
                      hintText: 'e.g. 952',
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
            const SizedBox(height: 12),

            // Stabled Station
            TextField(
              controller: _stabledCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Stabled Station (optional)',
                hintText: 'e.g. CGY',
                prefixIcon: Icon(Icons.home_work_outlined, size: 18),
              ),
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
