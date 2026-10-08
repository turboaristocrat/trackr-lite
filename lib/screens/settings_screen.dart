import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shift_log.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshSettings();
  }

  Future<void> refreshSettings() async {
    setState(() => _isLoading = true);
    final shift = await StorageService.getActiveShift();
    if (mounted) {
      setState(() {
        _activeShift = shift;
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Reset Everything to 0?'),
        content: const Text(
          'This will clear today\'s active shift, all block entries, completed history, and all notes/reminders.\n\nThe app will be set to a completely fresh clean slate for testing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset All to 0'),
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
                // Machine Profile Card
                _buildMachineProfileCard(),
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
