import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_log.dart';

class StorageService {
  static const _activeShiftKey = 'trackr_lite_active_shift';
  static const _historyKey = 'trackr_lite_history';
  static const _machineTypeKey = 'trackr_lite_machine_type';
  static const _machineNoKey = 'trackr_lite_machine_no';
  static const _divisionKey = 'trackr_lite_division';
  static const _sectionKey = 'trackr_lite_section';
  static const _readyStationKey = 'trackr_lite_ready_station';
  static const _stabledStationKey = 'trackr_lite_stabled_station';

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

    final mType = prefs.getString(_machineTypeKey) ?? 'UTV';
    final mNo = prefs.getString(_machineNoKey) ?? '005H';
    final div = prefs.getString(_divisionKey) ?? 'TVC';
    final sec = prefs.getString(_sectionKey) ?? 'KTYM';
    final rStation = prefs.getString(_readyStationKey) ?? 'CGY';
    final sStation = prefs.getString(_stabledStationKey) ?? 'KTYM';

    final fresh = ShiftLog(
      date: today,
      machineType: mType,
      machineNo: mNo,
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
    await prefs.setString(_machineTypeKey, log.machineType);
    await prefs.setString(_machineNoKey, log.machineNo);
    await prefs.setString(_divisionKey, log.division);
    await prefs.setString(_sectionKey, log.section);
    if (log.readyStation.isNotEmpty) {
      await prefs.setString(_readyStationKey, log.readyStation);
    }
    if (log.stabledStation.isNotEmpty) {
      await prefs.setString(_stabledStationKey, log.stabledStation);
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

  // --- Backup Export / Import ---
  static Future<String> exportBackupJson() async {
    final active = await getActiveShift();
    final history = await getHistory();
    final map = {
      'app': 'TRACKR_Lite',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'activeShift': active.toJson(),
      'history': history.map((h) => h.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Future<bool> importBackupJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

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

      return true;
    } catch (_) {
      return false;
    }
  }
}
