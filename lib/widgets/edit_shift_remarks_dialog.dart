import 'package:flutter/material.dart';
import '../services/storage_service.dart';
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

  Future<void> _showEditTemplatePrompt(int index, String currentText) async {
    final customCtrl = TextEditingController(text: currentText);

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Edit Remark Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update template wording. Changes will be saved for all future shifts.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customCtrl,
              autofocus: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Template Text',
                hintText: 'e.g. Kindly arrange one barrel diesel',
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      await StorageService.updateRemarkTemplate(index, updated);
      await _loadTemplates();
    }
  }

  Future<void> _showManageTemplatesDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Manage Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 22),
                  tooltip: 'Add Template',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showAddCustomTemplatePrompt();
                    _showManageTemplatesDialog();
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: _templates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No templates saved.\nTap + above to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _templates.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final tpl = entry.value;
                          final isDiesel = tpl.toLowerCase().contains('diesel');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDiesel ? Icons.local_gas_station_rounded : Icons.notes_rounded,
                                  size: 16,
                                  color: isDiesel ? AppTheme.amberAccent : AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tpl,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _showEditTemplatePrompt(idx, tpl);
                                    _showManageTemplatesDialog();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.redDanger),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    await StorageService.deleteRemarkTemplate(idx);
                                    await _loadTemplates();
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
    await _loadTemplates();
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
                            'Add',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showManageTemplatesDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 13, color: AppTheme.textSecondary),
                          SizedBox(width: 2),
                          Text(
                            'Manage',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
              else if (_templates.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'No templates yet. Tap "+ Add" above to create one.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _templates.map((tpl) {
                    final isDiesel = tpl.toLowerCase().contains('diesel');
                    return ActionChip(
                      avatar: Icon(
                        isDiesel ? Icons.local_gas_station_rounded : Icons.notes_rounded,
                        size: 13,
                        color: isDiesel ? AppTheme.amberAccent : AppTheme.primary,
                      ),
                      label: Text(
                        tpl,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: isDiesel
                          ? AppTheme.amberAccent.withValues(alpha: 0.1)
                          : AppTheme.surfaceContainerLow,
                      side: BorderSide(
                        color: isDiesel
                            ? AppTheme.amberAccent.withValues(alpha: 0.35)
                            : AppTheme.borderColor,
                      ),
                      onPressed: () => _appendTemplate(tpl),
                    );
                  }).toList(),
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
