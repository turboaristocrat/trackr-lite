import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _remarksCtrl = TextEditingController(text: widget.initialRemarks);
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
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
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add general remarks or notes for this shift (e.g. block delays, special instructions, machine conditions).',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarksCtrl,
                maxLines: 4,
                minLines: 2,
                autofocus: true,
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
