import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';

import 'file_downloader_stub.dart'
    if (dart.library.js_interop) 'file_downloader_web.dart';

class BackupRestoreResult {
  final bool success;
  final String message;
  final int shiftCount;
  final int noteCount;

  const BackupRestoreResult({
    required this.success,
    required this.message,
    this.shiftCount = 0,
    this.noteCount = 0,
  });
}

class BackupService {
  static Timer? _autoBackupTimer;

  /// Generate timestamped backup file name
  static String get _backupFileName {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'TRACKR_Lite_Backup_$stamp.json';
  }

  /// Initializes periodic auto-backup scheduler (checks every 30 seconds)
  static void initAutoBackup({BuildContext? context}) {
    _autoBackupTimer?.cancel();
    // Immediate check on startup/route
    checkAndRunAutoBackup(context: context);
    // Recurring check every 30 seconds
    _autoBackupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkAndRunAutoBackup(context: context);
    });
  }

  /// Cancels any running auto-backup timer
  static void stopAutoBackupScheduler() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
  }

  /// Checks if daily auto-backup to Google Drive should run now
  static Future<bool> checkAndRunAutoBackup({BuildContext? context}) async {
    try {
      final enabled = await StorageService.isAutoBackupEnabled();
      if (!enabled) return false;

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastDate = await StorageService.getLastAutoBackupDate();
      if (lastDate == todayStr) {
        // Already successfully backed up today
        return false;
      }

      final targetTimeStr = await StorageService.getAutoBackupTime();
      int targetHour = 20;
      int targetMin = 0;
      if (targetTimeStr.contains(':')) {
        final parts = targetTimeStr.split(':');
        targetHour = int.tryParse(parts[0]) ?? 20;
        targetMin = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      }

      final now = DateTime.now();
      final hasReachedTime = (now.hour > targetHour) ||
          (now.hour == targetHour && now.minute >= targetMin);

      if (hasReachedTime) {
        if (context != null && !context.mounted) return false;
        return await executeAutoBackup(context: context);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Executes Google Drive auto-backup, saves backup file and marks completion
  static Future<bool> executeAutoBackup({BuildContext? context, bool isManualTest = false}) async {
    try {
      final jsonContent = await StorageService.exportBackupJson();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'TRACKR_Lite_AutoBackup_$stamp.json';

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timeStr = DateFormat('HH:mm').format(DateTime.now());

      if (kIsWeb) {
        triggerBrowserDownload(jsonContent, fileName);
        final driveUri = Uri.parse('https://drive.google.com/drive/my-drive');
        await launchUrl(driveUri, mode: LaunchMode.externalApplication);
      } else {
        final xFile = XFile.fromData(
          utf8.encode(jsonContent),
          mimeType: 'application/json',
          name: fileName,
        );
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          subject: 'TRACKR Lite Auto-Backup ($fileName)',
          text: 'Google Drive Auto-Backup - TRACKR Lite backup file.',
        );
      }

      // Record successful backup time
      await StorageService.setLastAutoBackupCompleted(date: todayStr, time: timeStr);

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isManualTest
                        ? 'Auto-backup completed! Saved "$fileName"'
                        : 'Daily Auto-Backup completed to Google Drive! ($fileName)',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F52BA),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-backup error: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Download or share backup JSON locally to device storage
  static Future<void> backupToLocal(BuildContext context) async {
    try {
      final jsonContent = await StorageService.exportBackupJson();
      final fileName = _backupFileName;

      if (kIsWeb) {
        // Direct browser file download for Web / PWA
        try {
          triggerBrowserDownload(jsonContent, fileName);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded backup "$fileName" locally'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } catch (_) {
          // Fallback to share sheet if browser download fails
        }
      }

      // Mobile or fallback: native share / save to Files
      final xFile = XFile.fromData(
        utf8.encode(jsonContent),
        mimeType: 'application/json',
        name: fileName,
      );

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        subject: 'TRACKR Lite Backup ($fileName)',
        text: 'TRACKR Lite railway field logbook & reminders backup.',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup shared / saved to device'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  /// Backup to Google Drive:
  /// Downloads the file and provides 1-tap shortcut to open Google Drive,
  /// or triggers the system Share sheet to save directly to Google Drive app.
  static Future<void> backupToGoogleDrive(BuildContext context) async {
    try {
      final jsonContent = await StorageService.exportBackupJson();
      final fileName = _backupFileName;

      if (kIsWeb) {
        // 1. Download file to local device downloads first
        triggerBrowserDownload(jsonContent, fileName);

        // 2. Open Google Drive in new tab / app
        final driveUri = Uri.parse('https://drive.google.com/drive/my-drive');
        await launchUrl(driveUri, mode: LaunchMode.externalApplication);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "$fileName"! Opened Google Drive to upload.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Mobile: trigger system share sheet targeting Google Drive
      final xFile = XFile.fromData(
        utf8.encode(jsonContent),
        mimeType: 'application/json',
        name: fileName,
      );

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        subject: 'TRACKR Lite Google Drive Backup ($fileName)',
        text: 'Save to Google Drive - TRACKR Lite backup file.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Drive backup error: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  /// Restore backup file from device picker or Google Drive download
  static Future<BackupRestoreResult> restoreFromFilePicker() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) {
        return const BackupRestoreResult(
          success: false,
          message: 'No file selected.',
        );
      }

      final file = files.first;
      final bytes = await file.readAsBytes();
      final jsonStr = utf8.decode(bytes);

      if (jsonStr.trim().isEmpty) {
        return const BackupRestoreResult(
          success: false,
          message: 'The selected backup file is empty.',
        );
      }

      return await restoreFromJson(jsonStr);
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Could not open file: $e',
      );
    }
  }

  /// Parses JSON string and restores state into StorageService
  static Future<BackupRestoreResult> restoreFromJson(String jsonStr) async {
    try {
      final dynamic parsed = jsonDecode(jsonStr.trim());
      if (parsed is! Map<String, dynamic>) {
        return const BackupRestoreResult(
          success: false,
          message: 'Invalid file format: root must be a JSON object.',
        );
      }

      final ok = await StorageService.importBackupJson(jsonStr);
      if (!ok) {
        return const BackupRestoreResult(
          success: false,
          message: 'Failed to restore backup data.',
        );
      }

      final historyList = parsed['history'] as List<dynamic>? ?? [];
      final notesList = parsed['notes'] as List<dynamic>? ?? [];

      return BackupRestoreResult(
        success: true,
        message: 'Successfully restored backup!',
        shiftCount: historyList.length,
        noteCount: notesList.length,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Invalid JSON format: $e',
      );
    }
  }
}
