class BlockEntry {
  final String id;
  final String startTime;
  final String endTime;
  final String stationFrom;
  final String stationTo;
  final String line; // 'UP', 'DN', 'SL', 'Yard'
  final String activity; // 'Sleepers unloaded', 'Sleepers loaded', 'Tamping done', etc.
  final double output;
  final String outputUnit; // 'Nos', 'Sleepers', 'Km', 'Turnouts'
  final String remarks;
  final bool isTransit;

  const BlockEntry({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.stationFrom,
    required this.stationTo,
    this.line = 'DN',
    this.activity = 'Sleepers unloaded',
    this.output = 0.0,
    this.outputUnit = 'Nos',
    this.remarks = '',
    this.isTransit = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime,
    'endTime': endTime,
    'stationFrom': stationFrom,
    'stationTo': stationTo,
    'line': line,
    'activity': activity,
    'output': output,
    'outputUnit': outputUnit,
    'remarks': remarks,
    'isTransit': isTransit,
  };

  factory BlockEntry.fromJson(Map<String, dynamic> json) => BlockEntry(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
    stationFrom: json['stationFrom'] as String? ?? '',
    stationTo: json['stationTo'] as String? ?? '',
    line: json['line'] as String? ?? 'DN',
    activity: json['activity'] as String? ?? 'Sleepers unloaded',
    output: (json['output'] as num?)?.toDouble() ?? 0.0,
    outputUnit: json['outputUnit'] as String? ?? 'Nos',
    remarks: json['remarks'] as String? ?? '',
    isTransit: json['isTransit'] as bool? ?? false,
  );

  BlockEntry copyWith({
    String? id,
    String? startTime,
    String? endTime,
    String? stationFrom,
    String? stationTo,
    String? line,
    String? activity,
    double? output,
    String? outputUnit,
    String? remarks,
    bool? isTransit,
  }) {
    return BlockEntry(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      stationFrom: stationFrom ?? this.stationFrom,
      stationTo: stationTo ?? this.stationTo,
      line: line ?? this.line,
      activity: activity ?? this.activity,
      output: output ?? this.output,
      outputUnit: outputUnit ?? this.outputUnit,
      remarks: remarks ?? this.remarks,
      isTransit: isTransit ?? this.isTransit,
    );
  }
}
