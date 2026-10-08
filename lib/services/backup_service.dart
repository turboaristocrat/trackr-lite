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
  /// Generate timestamped backup file name
  static String get _backupFileName {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'TRACKR_Lite_Backup_$stamp.json';
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
