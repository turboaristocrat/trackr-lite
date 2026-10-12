import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'station_autocomplete_field.dart';

class EditShiftRemarksDialog extends StatefulWidget {
  final String initialRemarks;

  const EditShiftRemarksDialog({
    super.key,
    required this.initialRemarks,
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialRemarks,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => EditShiftRemarksDialog(initialRemarks: initialRemarks),
    );
  }

  @override
  State<EditShiftRemarksDialog> createState() => _EditShiftRemarksDialogState();
}

class _EditShiftRemarksDialogState extends State<EditShiftRemarksDialog> {
  late TextEditingController _remarksCtrl;
  List<String> _templates = [];
  bool _isLoadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _remarksCtrl = TextEditingController(text: widget.initialRemarks);
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final list = await StorageService.getRemarkTemplates();
    if (mounted) {
      setState(() {
        _templates = list;
        _isLoadingTemplates = false;
      });
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _appendTemplate(String text) {
    final current = _remarksCtrl.text.trim();
    if (current.isEmpty) {
      _remarksCtrl.text = text;
    } else {
      _remarksCtrl.text = '$current\n$text';
    }
    setState(() {});
  }

  Future<void> _showAddDieselPrompt() async {
    final litresCtrl = TextEditingController();
    final stationCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_gas_station_rounded, color: AppTheme.amberAccent, size: 22),
            SizedBox(width: 8),
            Text('Add Diesel Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quickly record diesel taken for the machine. Leave blank to insert placeholder.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: litresCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Quantity (Litres)',
                hintText: 'e.g. 200',
                prefixIcon: Icon(Icons.water_drop_outlined, size: 18),
                suffixText: 'Ltrs',
              ),
            ),
            const SizedBox(height: 10),
            StationAutocompleteField(
              controller: stationCtrl,
              label: 'Station (optional)',
              hintText: 'e.g. KTYM',
              prefixIcon: const Icon(Icons.ev_station_rounded, size: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Insert Template'),
          ),
        ],
      ),
    );

    if (result == true) {
      final litres = litresCtrl.text.trim();
      final station = stationCtrl.text.trim().toUpperCase();

      String text;
      if (litres.isNotEmpty && station.isNotEmpty) {
        text = 'Diesel filled: $litres Ltrs at $station.';
      } else if (litres.isNotEmpty) {
        text = 'Diesel filled: $litres Ltrs.';
      } else if (station.isNotEmpty) {
        text = 'Diesel filled: ___ Ltrs at $station.';
      } else {
        text = 'Diesel filled: ___ Ltrs at ___.';
      }
      _appendTemplate(text);
    }
  }

  Future<void> _showAddCustomTemplatePrompt() async {
    final customCtrl = TextEditingController();

    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_comment_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('New Remark Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter a template phrase. It will be saved for quick 1-tap reuse in future shifts.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Template Text',
                hintText: 'e.g. Block burst by 15 mins due to signal.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, customCtrl.text.trim()),
            child: const Text('Save & Add'),
          ),
        ],
      ),
    );

    if (added != null && added.isNotEmpty) {
      await StorageService.addRemarkTemplate(added);
      _appendTemplate(added);
      await _loadTemplates();
    }
  }

  void _save() {
    Navigator.pop(context, _remarksCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
          SizedBox(width: 8),
          Text(
            'Shift Remarks',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add general remarks for this shift (e.g. diesel refueling, block delays, track status).',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),

              // Templates Section
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.amberAccent),
                  const SizedBox(width: 4),
                  const Text(
                    'QUICK TEMPLATES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _showAddCustomTemplatePrompt,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: AppTheme.primary),
                          SizedBox(width: 2),
                          Text(
                            'Add Custom',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Template Chips
              if (_isLoadingTemplates)
                const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Dedicated Primary "Add Diesel" Action Chip
                    ActionChip(
                      avatar: const Icon(Icons.local_gas_station_rounded, size: 14, color: AppTheme.amberAccent),
                      label: const Text(
                        'Add Diesel',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: AppTheme.amberAccent.withValues(alpha: 0.12),
                      side: BorderSide(color: AppTheme.amberAccent.withValues(alpha: 0.4)),
                      onPressed: _showAddDieselPrompt,
                    ),

                    // Other Saved Templates
                    ..._templates
                        .where((t) => !t.toLowerCase().startsWith('diesel filled'))
                        .map((tpl) {
                      return ActionChip(
                        label: Text(
                          tpl,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor: AppTheme.surfaceContainerLow,
                        side: const BorderSide(color: AppTheme.borderColor),
                        onPressed: () => _appendTemplate(tpl),
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 14),

              // Text Area
              TextField(
                controller: _remarksCtrl,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'e.g. Work carried out smoothly under caution order.',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_remarksCtrl.text.isNotEmpty)
          TextButton(
            onPressed: () {
              _remarksCtrl.clear();
              _save();
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.redDanger)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Remarks'),
        ),
      ],
    );
  }
}
