import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'station_autocomplete_field.dart';

class EditMachineReadyDialog extends StatefulWidget {
  final String initialStation;
  final String initialTime;

  const EditMachineReadyDialog({
    super.key,
    required this.initialStation,
    required this.initialTime,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String initialStation,
    required String initialTime,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => EditMachineReadyDialog(
        initialStation: initialStation,
        initialTime: initialTime,
      ),
    );
  }

  @override
  State<EditMachineReadyDialog> createState() => _EditMachineReadyDialogState();
}

class _EditMachineReadyDialogState extends State<EditMachineReadyDialog> {
  late TextEditingController _stationCtrl;
  late TextEditingController _timeCtrl;

  @override
  void initState() {
    super.initState();
    _stationCtrl = TextEditingController(text: widget.initialStation);
    _timeCtrl = TextEditingController(text: widget.initialTime);
  }

  @override
  void dispose() {
    _stationCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
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
      setState(() => _timeCtrl.text = '$h:$m');
    }
  }

  void _save() {
    Navigator.pop(context, {
      'station': _stationCtrl.text.trim().toUpperCase(),
      'time': _timeCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppTheme.railSafetyGreen, size: 22),
          SizedBox(width: 8),
          Text(
            'Machine Ready (Start)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record the station and time where the machine was ready for duty at the start of shift.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              StationAutocompleteField(
                controller: _stationCtrl,
                label: 'Ready Station',
                hintText: 'e.g. CGY',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ready Time (hrs)',
                      hintText: '09:25',
                      prefixIcon: Icon(Icons.access_time_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Details'),
        ),
      ],
    );
  }
}
