import 'package:flutter/material.dart';
import '../models/shift_log.dart';
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
  late TextEditingController _readyStationCtrl;
  late TextEditingController _readyTimeCtrl;
  late TextEditingController _stabledStationCtrl;
  late TextEditingController _stabledTimeCtrl;

  @override
  void initState() {
    super.initState();
    _machineNameCtrl = TextEditingController(text: widget.currentShift.machineName);
    _divisionCtrl = TextEditingController(text: widget.currentShift.division);
    _sectionCtrl = TextEditingController(text: widget.currentShift.section);
    _readyStationCtrl = TextEditingController(text: widget.currentShift.readyStation);
    _readyTimeCtrl = TextEditingController(text: widget.currentShift.readyTime);
    _stabledStationCtrl = TextEditingController(text: widget.currentShift.stabledStation);
    _stabledTimeCtrl = TextEditingController(text: widget.currentShift.stabledTime);
  }

  @override
  void dispose() {
    _machineNameCtrl.dispose();
    _divisionCtrl.dispose();
    _sectionCtrl.dispose();
    _readyStationCtrl.dispose();
    _readyTimeCtrl.dispose();
    _stabledStationCtrl.dispose();
    _stabledTimeCtrl.dispose();
    super.dispose();
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
    final mName = _machineNameCtrl.text.trim().isEmpty ? 'UTV005H' : _machineNameCtrl.text.trim();
    final div = _divisionCtrl.text.trim().toUpperCase().isEmpty ? 'TVC' : _divisionCtrl.text.trim().toUpperCase();
    final sec = _sectionCtrl.text.trim().toUpperCase().isEmpty ? 'KTYM' : _sectionCtrl.text.trim().toUpperCase();

    final updated = widget.currentShift.copyWith(
      machineName: mName,
      division: div,
      section: sec,
      readyStation: _readyStationCtrl.text.trim().toUpperCase(),
      readyTime: _readyTimeCtrl.text.trim(),
      stabledStation: _stabledStationCtrl.text.trim().toUpperCase(),
      stabledTime: _stabledTimeCtrl.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 8),
          Text(
            'Shift Setup',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter machine & section details. TRACKR Lite remembers these automatically for future shifts.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              // ================= SECTION 1: MACHINE & DIVISION =================
              _buildSectionCard(
                title: 'Machine & Section',
                icon: Icons.precision_manufacturing_rounded,
                iconColor: AppTheme.primary,
                children: [
                  TextField(
                    controller: _machineNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Machine Name',
                      hintText: 'e.g. UTV005H or CSM 952',
                      prefixIcon: Icon(Icons.train_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
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
                        child: TextField(
                          controller: _sectionCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Section Code',
                            hintText: 'e.g. KTYM',
                            prefixIcon: Icon(Icons.signpost_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ================= SECTION 2: MACHINE READY =================
              _buildSectionCard(
                title: 'Machine Ready (Start)',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppTheme.railSafetyGreen,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: StationAutocompleteField(
                          controller: _readyStationCtrl,
                          label: 'Ready Station',
                          hintText: 'e.g. CGY',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _pickTime(_readyTimeCtrl),
                          borderRadius: BorderRadius.circular(12),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _readyTimeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ready Time',
                                hintText: '09:25',
                                prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ================= SECTION 3: MACHINE STABLE (BOTTOM) =================
              _buildSectionCard(
                title: 'Machine Stabled (End)',
                icon: Icons.flag_circle_outlined,
                iconColor: AppTheme.amberAccent,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: StationAutocompleteField(
                          controller: _stabledStationCtrl,
                          label: 'Stabled Station',
                          hintText: 'e.g. KTYM',
                          prefixIcon: const Icon(Icons.home_work_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _pickTime(_stabledTimeCtrl),
                          borderRadius: BorderRadius.circular(12),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _stabledTimeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Time (Opt)',
                                hintText: '17:30',
                                prefixIcon: Icon(Icons.access_time_filled_rounded, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
          child: const Text('Save Setup'),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: iconColor == AppTheme.primary ? AppTheme.textPrimary : iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
