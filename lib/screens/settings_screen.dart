import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shift_log.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../services/web_launcher_stub.dart'
    if (dart.library.js_interop) '../services/web_launcher_web.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_shift_dialog.dart';
import '../widgets/trackr_logo.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const SettingsScreen({super.key, this.onDataChanged});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  ShiftLog? _activeShift;
  List<String> _remarkTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshSettings();
  }

  Future<void> refreshSettings() async {
    setState(() => _isLoading = true);
    final shift = await StorageService.getActiveShift();
    final templates = await StorageService.getRemarkTemplates();
    if (mounted) {
      setState(() {
        _activeShift = shift;
        _remarkTemplates = templates;
        _isLoading = false;
      });
    }
  }

  Future<void> _editMachineSetup() async {
    if (_activeShift == null) return;
    final updated = await EditShiftDialog.show(context, _activeShift!);
    if (updated != null) {
      await StorageService.saveActiveShift(updated);
      setState(() => _activeShift = updated);
      widget.onDataChanged?.call();
    }
  }

  Future<void> _addNewTemplate() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_comment_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Add Remark Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter a phrase or template. It will appear for 1-tap insertion in the shift remarks tab.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Template Text',
                hintText: 'e.g. Engine oil topped up by 5 litres.',
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
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save Template'),
          ),
        ],
      ),
    );

    if (added != null && added.isNotEmpty) {
      await StorageService.addRemarkTemplate(added);
      await refreshSettings();
    }
  }

  Future<void> _editTemplate(int index, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Edit Remark Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update template wording for 1-tap reuse in shift remarks.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
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
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      await StorageService.updateRemarkTemplate(index, updated);
      await refreshSettings();
    }
  }

  Future<void> _deleteTemplate(int index) async {
    await StorageService.deleteRemarkTemplate(index);
    await refreshSettings();
  }

  Future<void> _resetTemplatesToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Reset Templates?'),
        content: const Text('Restore default railway remark templates? Custom templates will be reset.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.resetRemarkTemplates();
      await refreshSettings();
    }
  }

  Future<void> _handleLocalBackup() async {
    await BackupService.backupToLocal(context);
  }

  Future<void> _handleGoogleDriveBackup() async {
    await BackupService.backupToGoogleDrive(context);
  }

  Future<void> _handleRestore() async {
    final res = await BackupService.restoreFromFilePicker();
    if (!mounted) return;

    if (res.success) {
      await refreshSettings();
      if (!mounted) return;
      widget.onDataChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${res.message} (${res.shiftCount} shifts, ${res.noteCount} notes)'),
          backgroundColor: AppTheme.railSafetyGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.redDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleManualJsonPaste() async {
    final ctrl = TextEditingController();
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Paste Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste raw JSON backup below to restore your shift history & notes:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{\n  "app": "TRACKR_Lite", ...\n}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await BackupService.restoreFromJson(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, ok.success);
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );

    if (success == true) {
      await refreshSettings();
      widget.onDataChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: AppTheme.railSafetyGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCopyJson() async {
    final json = await StorageService.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Raw JSON copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.redDanger.withValues(alpha: 0.6), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.redDanger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.redDanger,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Reset All Data to 0?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.redDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.redDanger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppTheme.redDanger, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: This action cannot be undone!',
                      style: TextStyle(
                        color: AppTheme.redDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Resetting will permanently erase all local data from this device:',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 10),
            _buildResetWarningBullet('Active shift draft, blocks, outputs, and remarks'),
            _buildResetWarningBullet('All saved shift history logs'),
            _buildResetWarningBullet('All field notes and reminders'),
            _buildResetWarningBullet('Station preferences (Ready & Stabled stations)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Text(
                '💡 Tip: Use "Copy JSON" or "Export Backup File" before resetting if you need a copy of your records.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel / Keep Data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redDanger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 17),
            label: const Text('Reset to 0 State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.resetAllData();
      await refreshSettings();
      widget.onDataChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset to 0 (clean slate).'),
            backgroundColor: AppTheme.railSafetyGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildResetWarningBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.redDanger, fontSize: 13, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Settings & Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // PWA Field App Install Card
                _buildPwaInstallCard(),
                const SizedBox(height: 14),

                // Machine Profile Card
                _buildMachineProfileCard(),
                const SizedBox(height: 14),

                // Shift Remark Templates Card
                _buildRemarkTemplatesCard(),
                const SizedBox(height: 18),

                // Backup & Restore Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'BACKUP & CLOUD RESTORE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Backup Options Card
                _buildBackupCard(),
                const SizedBox(height: 18),

                // App Info & Version Card
                _buildAppInfoCard(),
              ],
            ),
    );
  }

  Widget _buildPwaInstallCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB324).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.install_mobile_rounded, color: Color(0xFF996800), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Install Field App',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Install to home screen for 1-tap offline use',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final accepted = await promptPwaInstall();
                if (!accepted && mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.phone_android_rounded, color: AppTheme.primary, size: 22),
                          SizedBox(width: 8),
                          Text('Install TRACKR Lite', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('To install this app on your phone:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 10),
                          Text('📱 On Android (Chrome):\n1. Tap the three dots (⋮) menu in top right.\n2. Tap "Install app" or "Add to Home screen".', style: TextStyle(fontSize: 12.5, height: 1.4)),
                          SizedBox(height: 10),
                          Text('🍎 On iPhone (Safari):\n1. Tap the Share button (square with arrow) at bottom.\n2. Scroll and tap "Add to Home Screen".', style: TextStyle(fontSize: 12.5, height: 1.4)),
                        ],
                      ),
                      actions: [
                        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got It')),
                      ],
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB324),
                foregroundColor: const Color(0xFF191C20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Install', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkTemplatesCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.amberAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppTheme.amberAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Remark Templates',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Quick phrases for 1-tap logging in remarks',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addNewTemplate,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_remarkTemplates.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.notes_rounded, color: AppTheme.textMuted, size: 28),
                    SizedBox(height: 6),
                    Text(
                      'No remark templates yet.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap "+ Add" above to create custom quick phrases.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              ..._remarkTemplates.asMap().entries.map((entry) {
                final idx = entry.key;
                final tpl = entry.value;
                final isDiesel = tpl.toLowerCase().contains('diesel');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDiesel ? Icons.local_gas_station_rounded : Icons.notes_rounded,
                        size: 16,
                        color: isDiesel ? AppTheme.amberAccent : AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _editTemplate(idx, tpl),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              tpl,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Edit Template',
                        onPressed: () => _editTemplate(idx, tpl),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.redDanger),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete Template',
                        onPressed: () => _deleteTemplate(idx),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetTemplatesToDefault,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Reset to Defaults', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineProfileCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.train_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Machine & Section Profile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Default configuration for daily block logs',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _editMachineSetup,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildProfileItem('Machine', _activeShift?.machineName ?? 'UTV005H'),
                _buildProfileItem('Division', _activeShift?.division ?? 'TVC'),
                _buildProfileItem('Section', _activeShift?.section ?? 'KTYM'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBackupCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secure Your Railway Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            const SizedBox(height: 4),
            const Text(
              'Backup includes active shifts, completed history, and all notes/reminders. Restore anytime to transfer to another phone or computer.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),

            // Google Drive Backup
            InkWell(
              onTap: _handleGoogleDriveBackup,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_to_drive_rounded, color: Color(0xFFE37400), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup to Google Drive',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Save backup directly to your Google Drive account',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Local Device Backup
            InkWell(
              onTap: _handleLocalBackup,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download_for_offline_rounded, color: Color(0xFF1976D2), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup to Local Storage / Files',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Download JSON file to device Downloads / Files',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Restore from File
            InkWell(
              onTap: _handleRestore,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.railSafetyGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restore_page_rounded, color: AppTheme.railSafetyGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restore from Backup File',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pick JSON file from Drive or Downloads to restore',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Secondary Quick Actions (Copy JSON / Paste JSON / Reset Data)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleCopyJson,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy JSON', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleManualJsonPaste,
                    icon: const Icon(Icons.paste_rounded, size: 14),
                    label: const Text('Paste JSON', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleResetAllData,
                icon: const Icon(Icons.restart_alt_rounded, size: 15, color: AppTheme.redDanger),
                label: const Text(
                  'Reset All Data to Zero (Clean Slate)',
                  style: TextStyle(fontSize: 12, color: AppTheme.redDanger, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.redDanger.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TrackrLogo(iconSize: 28, fontSize: 16),
            const SizedBox(height: 6),
            const Text(
              '© johnsankeyjob@gmail.com',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'v1.0.0 (Offline PWA)',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
