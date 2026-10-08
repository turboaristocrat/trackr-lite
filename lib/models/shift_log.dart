import 'block_entry.dart';

class ShiftLog {
  final String date; // YYYY-MM-DD
  final String machineType;
  final String machineNo;
  final String division;
  final String section;
  final String readyStation;
  final String readyTime;
  final String stabledStation;
  final String stabledTime;
  final List<BlockEntry> blocks;

  const ShiftLog({
    required this.date,
    required this.machineType,
    required this.machineNo,
    required this.division,
    required this.section,
    this.readyStation = '',
    this.readyTime = '',
    this.stabledStation = '',
    this.stabledTime = '',
    required this.blocks,
  });

  double get totalBlockOutput => blocks
      .where((b) => !b.isTransit)
      .fold(0.0, (sum, b) => sum + b.output);

  double get totalTransitKm => blocks
      .where((b) => b.isTransit)
      .fold(0.0, (sum, b) => sum + b.output);

  int get blockCount => blocks.where((b) => !b.isTransit).length;
  int get transitCount => blocks.where((b) => b.isTransit).length;

  // Group outputs by activity (e.g. 'Sleepers loaded', 'Sleepers unloaded')
  Map<String, double> get outputByActivity {
    final map = <String, double>{};
    for (final b in blocks) {
      if (!b.isTransit && b.output > 0) {
        final act = b.activity.trim().isNotEmpty ? b.activity.trim() : 'Output';
        map[act] = (map[act] ?? 0.0) + b.output;
      }
    }
    return map;
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'machineType': machineType,
    'machineNo': machineNo,
    'division': division,
    'section': section,
    'readyStation': readyStation,
    'readyTime': readyTime,
    'stabledStation': stabledStation,
    'stabledTime': stabledTime,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory ShiftLog.fromJson(Map<String, dynamic> json) => ShiftLog(
    date: json['date'] as String? ?? '',
    machineType: json['machineType'] as String? ?? 'UTV',
    machineNo: json['machineNo'] as String? ?? '005H',
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
  );

  ShiftLog copyWith({
    String? date,
    String? machineType,
    String? machineNo,
    String? division,
    String? section,
    String? readyStation,
    String? readyTime,
    String? stabledStation,
    String? stabledTime,
    List<BlockEntry>? blocks,
  }) {
    return ShiftLog(
      date: date ?? this.date,
      machineType: machineType ?? this.machineType,
      machineNo: machineNo ?? this.machineNo,
      division: division ?? this.division,
      section: section ?? this.section,
      readyStation: readyStation ?? this.readyStation,
      readyTime: readyTime ?? this.readyTime,
      stabledStation: stabledStation ?? this.stabledStation,
      stabledTime: stabledTime ?? this.stabledTime,
      blocks: blocks ?? this.blocks,
    );
  }
}
