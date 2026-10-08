import 'block_entry.dart';

class ShiftLog {
  final String date; // YYYY-MM-DD
  final String machineType;
  final String machineNo;
  final String division;
  final String section;
  final String stabledStation;
  final List<BlockEntry> blocks;

  const ShiftLog({
    required this.date,
    required this.machineType,
    required this.machineNo,
    required this.division,
    required this.section,
    this.stabledStation = '',
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

  Map<String, dynamic> toJson() => {
    'date': date,
    'machineType': machineType,
    'machineNo': machineNo,
    'division': division,
    'section': section,
    'stabledStation': stabledStation,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory ShiftLog.fromJson(Map<String, dynamic> json) => ShiftLog(
    date: json['date'] as String? ?? '',
    machineType: json['machineType'] as String? ?? 'CSM',
    machineNo: json['machineNo'] as String? ?? '',
    division: json['division'] as String? ?? 'TVC',
    section: json['section'] as String? ?? 'KTYM',
    stabledStation: json['stabledStation'] as String? ?? '',
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
    String? stabledStation,
    List<BlockEntry>? blocks,
  }) {
    return ShiftLog(
      date: date ?? this.date,
      machineType: machineType ?? this.machineType,
      machineNo: machineNo ?? this.machineNo,
      division: division ?? this.division,
      section: section ?? this.section,
      stabledStation: stabledStation ?? this.stabledStation,
      blocks: blocks ?? this.blocks,
    );
  }
}
