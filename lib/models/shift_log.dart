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
    required this.blocks,
    this.reminders = const [],
  });

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

  // Group outputs by activity across all items in all blocks
  Map<String, double> get outputByActivity {
    final map = <String, double>{};
    for (final b in blocks) {
      if (!b.isTransit) {
        for (final item in b.items) {
          if (item.output > 0) {
            final act = item.activity.trim().isNotEmpty ? item.activity.trim() : 'Output';
            map[act] = (map[act] ?? 0.0) + item.output;
          }
        }
      }
    }
    return map;
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
      blocks: blocks ?? this.blocks,
      reminders: reminders ?? this.reminders,
    );
  }
}
