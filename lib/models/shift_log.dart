import 'block_entry.dart';
import 'reminder_item.dart';

class ShiftLog {
  final String date; // YYYY-MM-DD
  final String machineName; // e.g. 'UTV005H' or 'CSM 952'
  final String division; // e.g. 'TVC'
  final String section; // e.g. 'KTYM'
  final String readyStation;
  final String readyTime;
  final String stabledStation;
  final String stabledTime;
  final String remarks;
  final bool isNightShift;
  final List<BlockEntry> blocks;
  final List<ReminderItem> reminders;

  const ShiftLog({
    required this.date,
    required this.machineName,
    required this.division,
    required this.section,
    this.readyStation = '',
    this.readyTime = '',
    this.stabledStation = '',
    this.stabledTime = '',
    this.remarks = '',
    this.isNightShift = false,
    required this.blocks,
    this.reminders = const [],
  });

  /// Formatted date string, handling single day (dd.MM.yyyy)
  /// and night shifts spanning across two days (e.g. 12/13/10/2026)
  String get formattedDate {
    try {
      final dt = DateTime.parse(date);
      if (isNightShift) {
        final nextDay = dt.add(const Duration(days: 1));
        final d1 = dt.day.toString().padLeft(2, '0');
        final d2 = nextDay.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final y = dt.year.toString();
        if (dt.month == nextDay.month) {
          return '$d1/$d2.$m.$y';
        } else {
          final m2 = nextDay.month.toString().padLeft(2, '0');
          return '$d1.$m/$d2.$m2.$y';
        }
      } else {
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final y = dt.year.toString();
        return '$d.$m.$y';
      }
    } catch (_) {
      return date;
    }
  }

  // Backward compatibility getters
  String get machineType => machineName;
  String get machineNo => '';

  double get totalBlockOutput => blocks
      .where((b) => !b.isTransit)
      .fold(0.0, (sum, b) => sum + b.output);

  double get totalTransitKm => blocks
      .where((b) => b.isTransit)
      .fold(0.0, (sum, b) => sum + b.output);

  int get blockCount => blocks.where((b) => !b.isTransit).length;
  int get transitCount => blocks.where((b) => b.isTransit).length;

  // Helper to split activity into base material and action (e.g. 'Rails loaded' -> ('Rails', 'loaded'))
  static (String base, String action) parseActivity(String activity) {
    final trimmed = activity.trim();
    final match = RegExp(
      r'^(.*?)\s+(loaded|unloaded|loading|unloading)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (match != null) {
      final base = match.group(1)!.trim();
      final action = match.group(2)!.trim().toLowerCase();
      return (base, action);
    }
    return (trimmed, '');
  }

  // Priority ranking for actions within the same base material
  static int actionRank(String action) {
    switch (action.toLowerCase()) {
      case 'loaded':
      case 'loading':
        return 0;
      case 'unloaded':
      case 'unloading':
        return 1;
      default:
        return 2;
    }
  }

  // Group outputs by activity across all items in all blocks (similar items kept together)
  Map<String, double> get outputByActivity {
    final rawMap = <String, double>{};
    final baseFirstSeen = <String, int>{};
    int seenOrder = 0;

    for (final b in blocks) {
      if (!b.isTransit) {
        for (final item in b.items) {
          if (item.output > 0) {
            final act = item.activity.trim().isNotEmpty ? item.activity.trim() : 'Output';
            rawMap[act] = (rawMap[act] ?? 0.0) + item.output;

            final (base, _) = parseActivity(act);
            baseFirstSeen.putIfAbsent(base.toLowerCase(), () => seenOrder++);
          }
        }
      }
    }

    if (rawMap.isEmpty) return rawMap;

    // Sort entries so similar items (e.g. Rails loaded & Rails unloaded) are adjacent
    final sortedKeys = rawMap.keys.toList()
      ..sort((a, b) {
        final (baseA, actionA) = parseActivity(a);
        final (baseB, actionB) = parseActivity(b);

        // Group by base material order of first appearance
        if (baseA.toLowerCase() != baseB.toLowerCase()) {
          final orderA = baseFirstSeen[baseA.toLowerCase()] ?? 999;
          final orderB = baseFirstSeen[baseB.toLowerCase()] ?? 999;
          return orderA.compareTo(orderB);
        }

        // Within same base material: loaded before unloaded
        final rankA = actionRank(actionA);
        final rankB = actionRank(actionB);
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        return a.compareTo(b);
      });

    final sortedMap = <String, double>{};
    for (final k in sortedKeys) {
      sortedMap[k] = rawMap[k]!;
    }
    return sortedMap;
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'machineName': machineName,
    'division': division,
    'section': section,
    'readyStation': readyStation,
    'readyTime': readyTime,
    'stabledStation': stabledStation,
    'stabledTime': stabledTime,
    'remarks': remarks,
    'isNightShift': isNightShift,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'reminders': reminders.map((r) => r.toJson()).toList(),
  };

  factory ShiftLog.fromJson(Map<String, dynamic> json) {
    String mName = json['machineName'] as String? ?? '';
    if (mName.isEmpty) {
      final t = json['machineType'] as String? ?? 'UTV';
      final n = json['machineNo'] as String? ?? '005H';
      mName = '$t$n'.trim();
    }

    final remindersList = (json['reminders'] as List<dynamic>?)
            ?.map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ShiftLog(
      date: json['date'] as String? ?? '',
      machineName: mName.isNotEmpty ? mName : 'UTV005H',
      division: json['division'] as String? ?? 'TVC',
      section: json['section'] as String? ?? 'KTYM',
      readyStation: json['readyStation'] as String? ?? '',
      readyTime: json['readyTime'] as String? ?? '',
      stabledStation: json['stabledStation'] as String? ?? '',
      stabledTime: json['stabledTime'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      isNightShift: json['isNightShift'] as bool? ?? false,
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map((e) => BlockEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reminders: remindersList,
    );
  }

  ShiftLog copyWith({
    String? date,
    String? machineName,
    String? division,
    String? section,
    String? readyStation,
    String? readyTime,
    String? stabledStation,
    String? stabledTime,
    String? remarks,
    bool? isNightShift,
    List<BlockEntry>? blocks,
    List<ReminderItem>? reminders,
  }) {
    return ShiftLog(
      date: date ?? this.date,
      machineName: machineName ?? this.machineName,
      division: division ?? this.division,
      section: section ?? this.section,
      readyStation: readyStation ?? this.readyStation,
      readyTime: readyTime ?? this.readyTime,
      stabledStation: stabledStation ?? this.stabledStation,
      stabledTime: stabledTime ?? this.stabledTime,
      remarks: remarks ?? this.remarks,
      isNightShift: isNightShift ?? this.isNightShift,
      blocks: blocks ?? this.blocks,
      reminders: reminders ?? this.reminders,
    );
  }
}
