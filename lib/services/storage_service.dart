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

  // --- Active Shift ---
  static Future<ShiftLog> getActiveShift() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = prefs.getString(_activeShiftKey);

    if (raw != null) {
      try {
        final log = ShiftLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (log.date == today) return log;
      } catch (_) {}
    }

    // Fallbacks or remembered preferences
    final mName = prefs.getString(_machineNameKey) ??
        '${prefs.getString('trackr_lite_machine_type') ?? 'UTV'}${prefs.getString('trackr_lite_machine_no') ?? '005H'}';
    final div = prefs.getString(_divisionKey) ?? 'TVC';
    final sec = prefs.getString(_sectionKey) ?? 'KTYM';
    final rStation = prefs.getString(_readyStationKey) ?? 'CGY';
    final sStation = prefs.getString(_stabledStationKey) ?? 'KTYM';

    final fresh = ShiftLog(
      date: today,
      machineName: mName.isNotEmpty ? mName : 'UTV005H',
      division: div,
      section: sec,
      readyStation: rStation,
      readyTime: '09:25',
      stabledStation: sStation,
      blocks: [],
    );
    await saveActiveShift(fresh);
    return fresh;
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
      // Default initial notes if empty
      return const [
        ReminderItem(id: 'r1', text: 'Check hydraulic oil & system pressure'),
        ReminderItem(id: 'r2', text: 'Diesel refueling required at depot'),
        ReminderItem(id: 'r3', text: 'Verify tines/clamp condition'),
      ];
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

      return true;
    } catch (_) {
      return false;
    }
  }
}
