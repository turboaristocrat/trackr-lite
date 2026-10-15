import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movement_entry.dart';
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
  static const _movementOverridesKey = 'trackr_lite_movement_overrides';
  static const _autoBackupEnabledKey = 'trackr_lite_auto_backup_enabled';
  static const _autoBackupTimeKey = 'trackr_lite_auto_backup_time';
  static const _lastAutoBackupDateKey = 'trackr_lite_last_auto_backup_date';
  static const _lastAutoBackupTimeKey = 'trackr_lite_last_auto_backup_time';

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

        // At end of day rollover, cross-check and auto-save previous day's shift data to history datewise
        if (log.date != today && hasActiveData) {
          await saveOrUpdateHistoryShift(log);
        }

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
    await prefs.remove(_movementOverridesKey);
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

  static Future<String> getMachineName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_machineNameKey) ?? 'UTV005H';
  }

  static Future<String> getDivision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_divisionKey) ?? 'TVC';
  }

  // --- Auto Backup Settings ---
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  static Future<String> getAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupTimeKey) ?? '20:00';
  }

  static Future<void> setAutoBackupTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoBackupTimeKey, time);
  }

  static Future<String?> getLastAutoBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastAutoBackupDateKey);
  }

  static Future<String?> getLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastAutoBackupTimeKey);
  }

  static Future<void> setLastAutoBackupCompleted({required String date, required String time}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoBackupDateKey, date);
    await prefs.setString(_lastAutoBackupTimeKey, time);
  }

  /// Saves or updates the current shift in History datewise.
  /// Does NOT clear the active shift, so user can keep editing if they want.
  /// If the shift for this date already exists in history:
  /// - If content is identical: returns [SaveHistoryResult.noChanges]
  /// - If content differs: updates it and returns [SaveHistoryResult.updated]
  /// Otherwise inserts it and returns [SaveHistoryResult.savedNew]
  static Future<SaveHistoryResult> saveOrUpdateHistoryShift(ShiftLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    final existingIndex = history.indexWhere((h) => h.date == log.date && h.isNightShift == log.isNightShift);
    if (existingIndex != -1) {
      final existingJson = jsonEncode(history[existingIndex].toJson());
      final currentJson = jsonEncode(log.toJson());

      if (existingJson == currentJson) {
        return SaveHistoryResult.noChanges;
      }

      // Update existing history entry with cross-checked changes
      history[existingIndex] = log;
      _sortHistoryDatewise(history);
      final rawList = history.map((h) => h.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(rawList));
      return SaveHistoryResult.updated;
    } else {
      // New shift entry in history
      history.insert(0, log);
      _sortHistoryDatewise(history);
      final rawList = history.map((h) => h.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(rawList));
      return SaveHistoryResult.savedNew;
    }
  }

  static void _sortHistoryDatewise(List<ShiftLog> list) {
    list.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return (b.isNightShift ? 1 : 0).compareTo(a.isNightShift ? 1 : 0);
    });
  }

  static Future<void> completeAndArchiveShift(ShiftLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    history.removeWhere((h) => h.date == log.date && h.isNightShift == log.isNightShift);
    history.insert(0, log);
    _sortHistoryDatewise(history);

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
      final history = list.map((e) => ShiftLog.fromJson(e as Map<String, dynamic>)).toList();
      _sortHistoryDatewise(history);
      return history;
    } catch (_) {
      return [];
    }
  }

  static Future<ShiftLog?> getHistoryShiftForDate(String date, {bool? isNightShift}) async {
    final history = await getHistory();
    try {
      if (isNightShift != null) {
        return history.firstWhere((h) => h.date == date && h.isNightShift == isNightShift);
      }
      return history.firstWhere((h) => h.date == date);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteHistoryItem(String date, {bool? isNightShift}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    if (isNightShift != null) {
      history.removeWhere((h) => h.date == date && h.isNightShift == isNightShift);
    } else {
      history.removeWhere((h) => h.date == date);
    }
    _sortHistoryDatewise(history);
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

  // --- Machine Movement Overrides ---
  static Future<Map<String, MovementDayItem>> getMovementOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementOverridesKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, MovementDayItem.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveMovementOverride(MovementDayItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getMovementOverrides();
    current[item.date] = item.copyWith(isManualOverride: true);
    final rawMap = current.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_movementOverridesKey, jsonEncode(rawMap));
  }

  static Future<void> deleteMovementOverride(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getMovementOverrides();
    current.remove(date);
    final rawMap = current.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_movementOverridesKey, jsonEncode(rawMap));
  }

  static Future<void> clearMovementOverridesForMonth(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getMovementOverrides();
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    current.removeWhere((k, _) => k.startsWith(prefix));
    final rawMap = current.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_movementOverridesKey, jsonEncode(rawMap));
  }

  // --- Backup Export / Import ---
  static Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final active = await getActiveShift();
    final history = await getHistory();
    final notes = await getNotes();
    final movementOverrides = await getMovementOverrides();

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
      'autoBackup': {
        'enabled': await isAutoBackupEnabled(),
        'time': await getAutoBackupTime(),
        'lastDate': await getLastAutoBackupDate(),
        'lastTime': await getLastAutoBackupTime(),
      },
      'activeShift': active.toJson(),
      'history': history.map((h) => h.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'remarkTemplates': await getRemarkTemplates(),
      'movementOverrides': movementOverrides.map((k, v) => MapEntry(k, v.toJson())),
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

      if (map['autoBackup'] is Map<String, dynamic>) {
        final ab = map['autoBackup'] as Map<String, dynamic>;
        if (ab['enabled'] is bool) await setAutoBackupEnabled(ab['enabled'] as bool);
        if (ab['time'] is String) await setAutoBackupTime(ab['time'] as String);
        if (ab['lastDate'] is String && ab['lastTime'] is String) {
          await setLastAutoBackupCompleted(date: ab['lastDate'] as String, time: ab['lastTime'] as String);
        }
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

      if (map['movementOverrides'] != null) {
        final overrides = (map['movementOverrides'] as Map<String, dynamic>);
        await prefs.setString(_movementOverridesKey, jsonEncode(overrides));
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
