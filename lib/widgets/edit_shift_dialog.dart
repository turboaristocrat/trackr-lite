import 'package:flutter/material.dart';
import '../models/shift_log.dart';
import '../services/station_service.dart';
import '../theme/app_theme.dart';
import 'station_autocomplete_field.dart';

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
  late TextEditingController _machineNameCtrl;
  late TextEditingController _divisionCtrl;
  late TextEditingController _sectionCtrl;

  @override
  void initState() {
    super.initState();
    _machineNameCtrl = TextEditingController(text: widget.currentShift.machineName);
    _divisionCtrl = TextEditingController(text: widget.currentShift.division);
    _sectionCtrl = TextEditingController(text: widget.currentShift.section);
    _sectionCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _machineNameCtrl.dispose();
    _divisionCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final mName = _machineNameCtrl.text.trim().isEmpty ? 'UTV005H' : _machineNameCtrl.text.trim();
    final div = _divisionCtrl.text.trim().toUpperCase().isEmpty ? 'TVC' : _divisionCtrl.text.trim().toUpperCase();
    final sec = _sectionCtrl.text.trim().toUpperCase().isEmpty ? 'KTYM' : _sectionCtrl.text.trim().toUpperCase();

    final updated = widget.currentShift.copyWith(
      machineName: mName,
      division: div,
      section: sec,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final secCode = _sectionCtrl.text.trim().toUpperCase();
    final matchedStationName = secCode.isNotEmpty ? StationService.getStationName(secCode) : '';
    final hasStationDetails = matchedStationName.isNotEmpty && matchedStationName.toUpperCase() != secCode;

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 8),
          Text(
            'Machine & Section Setup',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure machine and section once. TRACKR Lite automatically remembers them for every shift.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _machineNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Machine Name',
                  hintText: 'e.g. UTV500 or CSM 952',
                  prefixIcon: Icon(Icons.train_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _divisionCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Division',
                        hintText: 'e.g. TVC',
                        prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StationAutocompleteField(
                          controller: _sectionCtrl,
                          label: 'Section Code',
                          hintText: 'e.g. ERS or KTYM',
                          prefixIcon: const Icon(Icons.signpost_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Station details preview below section input
              if (hasStationDetails) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 15, color: AppTheme.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$secCode: $matchedStationName',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          child: const Text('Save Setup'),
        ),
      ],
    );
  }
}
