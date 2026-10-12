import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_item.dart';
import '../models/shift_log.dart';

enum SaveHistoryResult {
  savedNew,
  updated,
  noChanges,
}

class StorageService {
  static const _activeShiftKey = 'trackr_lite_active_shift';
  static const _historyKey = 'trackr_lite_history';
  static const _machineNameKey = 'trackr_lite_machine_name';
  static const _divisionKey = 'trackr_lite_division';
  static const _sectionKey = 'trackr_lite_section';
  static const _readyStationKey = 'trackr_lite_ready_station';
  static const _stabledStationKey = 'trackr_lite_stabled_station';
  static const _notesKey = 'trackr_lite_notes';
  static const _remarkTemplatesKey = 'trackr_lite_remark_templates_v2';
  static const _legacyRemarkTemplatesKey = 'trackr_lite_remark_templates';

  static const List<String> defaultRemarkTemplates = [
    'Kindly arrange one barrel diesel',
  ];

  static const List<String> _obsoleteDefaultTemplates = [
    'Diesel filled: ___ Ltrs at ___',
    'Track attended and fit for traffic.',
    'Caution order observed.',
    'Machine under maintenance / inspection.',
  ];

  // --- Remark Templates ---
  static Future<List<String>> getRemarkTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_remarkTemplatesKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
        // Return list even if empty, allowing the user to delete all templates completely
        return list;
      } catch (_) {}
    }

    // Migration from legacy v1 storage if v2 is not yet initialized
    final legacyRaw = prefs.getString(_legacyRemarkTemplatesKey);
    if (legacyRaw != null) {
      try {
        final legacyList = (jsonDecode(legacyRaw) as List<dynamic>).map((e) => e.toString()).toList();
        // Remove obsolete defaults, preserving only user custom templates
        final customOnly = legacyList.where((t) {
          final lower = t.toLowerCase();
          return !_obsoleteDefaultTemplates.any((obs) => obs.toLowerCase() == lower) &&
              !lower.startsWith('diesel filled:');
        }).toList();

        final migrated = customOnly.isNotEmpty ? customOnly : List<String>.from(defaultRemarkTemplates);
        await saveRemarkTemplates(migrated);
        return migrated;
      } catch (_) {}
    }

    // Default initialization
    final initial = List<String>.from(defaultRemarkTemplates);
    await saveRemarkTemplates(initial);
    return initial;
  }

  static Future<void> saveRemarkTemplates(List<String> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_remarkTemplatesKey, jsonEncode(templates));
  }

  static Future<void> addRemarkTemplate(String template) async {
    final list = await getRemarkTemplates();
    final trimmed = template.trim();
    if (trimmed.isNotEmpty && !list.contains(trimmed)) {
      list.add(trimmed);
      await saveRemarkTemplates(list);
    }
  }

  static Future<void> updateRemarkTemplate(int index, String newText) async {
    final list = await getRemarkTemplates();
    final trimmed = newText.trim();
    if (index >= 0 && index < list.length && trimmed.isNotEmpty) {
      list[index] = trimmed;
      await saveRemarkTemplates(list);
    }
  }

  static Future<void> deleteRemarkTemplate(int index) async {
    final list = await getRemarkTemplates();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await saveRemarkTemplates(list);
    }
  }

  static Future<void> resetRemarkTemplates() async {
    await saveRemarkTemplates(List<String>.from(defaultRemarkTemplates));
  }

  // --- Active Shift ---
  static Future<ShiftLog> getActiveShift() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = prefs.getString(_activeShiftKey);

    if (raw != null) {
      try {
        final log = ShiftLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        // Preserve active shift across app updates, date rollovers, and night shifts
        // whenever the shift has any user data (blocks, remarks, or station times),
        // or if it was created for today.
        final hasActiveData = log.blocks.isNotEmpty ||
            log.remarks.trim().isNotEmpty ||
            log.readyTime.trim().isNotEmpty ||
            log.stabledTime.trim().isNotEmpty ||
            log.isNightShift;

        if (log.date == today || hasActiveData) {
          return log;
        }

        // If it was a completely blank template from a previous day, roll date forward
        // while safely keeping their machine, division, section preferences.
        final updated = log.copyWith(date: today);
        await saveActiveShift(updated);
        return updated;
      } catch (_) {}
    }

    // Fallbacks or remembered preferences
    final mName = prefs.getString(_machineNameKey) ?? 'UTV005H';
    final div = prefs.getString(_divisionKey) ?? 'TVC';
    final sec = prefs.getString(_sectionKey) ?? '';
    final rStation = prefs.getString(_readyStationKey) ?? '';
    final sStation = prefs.getString(_stabledStationKey) ?? '';

    final fresh = ShiftLog(
      date: today,
      machineName: mName,
      division: div,
      section: sec,
      readyStation: rStation,
      readyTime: '',
      stabledStation: sStation,
      stabledTime: '',
      blocks: [],
    );
    await saveActiveShift(fresh);
    return fresh;
  }

  /// Clears all stored data (history, active shift, notes) for a clean slate
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeShiftKey);
    await prefs.remove(_historyKey);
    await prefs.remove(_notesKey);
    await prefs.remove(_readyStationKey);
    await prefs.remove(_stabledStationKey);
  }

  static Future<void> saveActiveShift(ShiftLog log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeShiftKey, jsonEncode(log.toJson()));
    await prefs.setString(_machineNameKey, log.machineName);
    await prefs.setString(_divisionKey, log.division);
    await prefs.setString(_sectionKey, log.section);
    if (log.readyStation.isNotEmpty) {
      await prefs.setString(_readyStationKey, log.readyStation);
    }
    if (log.stabledStation.isNotEmpty) {
      await prefs.setString(_stabledStationKey, log.stabledStation);
    }
  }

  /// Saves or updates the current shift in History.
  /// Does NOT clear the active shift, so user can keep editing if they want.
  /// If the shift for this date already exists in history:
  /// - If content is identical: returns [SaveHistoryResult.noChanges]
  /// - If content differs: updates it and returns [SaveHistoryResult.updated]
  /// Otherwise inserts it and returns [SaveHistoryResult.savedNew]
  static Future<SaveHistoryResult> saveOrUpdateHistoryShift(ShiftLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    final existingIndex = history.indexWhere((h) => h.date == log.date);
    if (existingIndex != -1) {
      final existingJson = jsonEncode(history[existingIndex].toJson());
      final currentJson = jsonEncode(log.toJson());

      if (existingJson == currentJson) {
        return SaveHistoryResult.noChanges;
      }

      // Update existing history entry
      history[existingIndex] = log;
      final rawList = history.map((h) => h.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(rawList));
      return SaveHistoryResult.updated;
    } else {
      // New shift entry in history
      history.insert(0, log);
      final rawList = history.map((h) => h.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(rawList));
      return SaveHistoryResult.savedNew;
    }
  }

  static Future<void> completeAndArchiveShift(ShiftLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    history.removeWhere((h) => h.date == log.date);
    history.insert(0, log);

    final rawList = history.map((h) => h.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(rawList));
    await prefs.remove(_activeShiftKey);
  }

  // --- History ---
  static Future<List<ShiftLog>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ShiftLog.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteHistoryItem(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere((h) => h.date == date);
    final rawList = history.map((h) => h.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(rawList));
  }

  // --- Notes & Reminders ---
  static Future<List<ReminderItem>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ReminderItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNotes(List<ReminderItem> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = notes.map((n) => n.toJson()).toList();
    await prefs.setString(_notesKey, jsonEncode(rawList));
  }

  // --- Backup Export / Import ---
  static Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final active = await getActiveShift();
    final history = await getHistory();
    final notes = await getNotes();

    final preferences = {
      'machineName': prefs.getString(_machineNameKey) ?? active.machineName,
      'division': prefs.getString(_divisionKey) ?? active.division,
      'section': prefs.getString(_sectionKey) ?? active.section,
      'readyStation': prefs.getString(_readyStationKey) ?? active.readyStation,
      'stabledStation': prefs.getString(_stabledStationKey) ?? active.stabledStation,
    };

    final map = {
      'app': 'TRACKR_Lite',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'preferences': preferences,
      'activeShift': active.toJson(),
      'history': history.map((h) => h.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'remarkTemplates': await getRemarkTemplates(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Future<bool> importBackupJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      if (map['preferences'] is Map<String, dynamic>) {
        final p = map['preferences'] as Map<String, dynamic>;
        if (p['machineName'] != null) await prefs.setString(_machineNameKey, p['machineName'] as String);
        if (p['division'] != null) await prefs.setString(_divisionKey, p['division'] as String);
        if (p['section'] != null) await prefs.setString(_sectionKey, p['section'] as String);
        if (p['readyStation'] != null) await prefs.setString(_readyStationKey, p['readyStation'] as String);
        if (p['stabledStation'] != null) await prefs.setString(_stabledStationKey, p['stabledStation'] as String);
      }

      if (map['history'] != null) {
        final list = (map['history'] as List<dynamic>)
            .map((e) => ShiftLog.fromJson(e as Map<String, dynamic>))
            .toList();
        await prefs.setString(_historyKey, jsonEncode(list.map((h) => h.toJson()).toList()));
      }

      if (map['activeShift'] != null) {
        final active = ShiftLog.fromJson(map['activeShift'] as Map<String, dynamic>);
        await saveActiveShift(active);
      }

      if (map['notes'] != null) {
        final notesList = (map['notes'] as List<dynamic>)
            .map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveNotes(notesList);
      }

      if (map['remarkTemplates'] != null) {
        final templatesList = (map['remarkTemplates'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        await saveRemarkTemplates(templatesList);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
