class WorkItem {
  final String activity; // e.g. 'Sleepers unloaded'
  final double output;
  final String outputUnit; // 'Nos', 'Sleepers', 'Km', etc.

  const WorkItem({
    required this.activity,
    required this.output,
    this.outputUnit = 'Nos',
  });

  Map<String, dynamic> toJson() => {
    'activity': activity,
    'output': output,
    'outputUnit': outputUnit,
  };

  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
    activity: json['activity'] as String? ?? 'Sleepers unloaded',
    output: (json['output'] as num?)?.toDouble() ?? 0.0,
    outputUnit: json['outputUnit'] as String? ?? 'Nos',
  );

  WorkItem copyWith({
    String? activity,
    double? output,
    String? outputUnit,
  }) {
    return WorkItem(
      activity: activity ?? this.activity,
      output: output ?? this.output,
      outputUnit: outputUnit ?? this.outputUnit,
    );
  }
}

class BlockEntry {
  final String id;
  final String startTime;
  final String endTime;
  final String stationFrom;
  final String stationTo;
  final String line; // 'UP', 'DN', 'Both', 'SL', 'Yard'
  final List<WorkItem> items;
  final String remarks;
  final bool isTransit;

  const BlockEntry({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.stationFrom,
    required this.stationTo,
    this.line = 'UP',
    this.items = const [],
    this.remarks = '',
    this.isTransit = false,
  });

  factory BlockEntry.singleItem({
    required String id,
    required String startTime,
    required String endTime,
    required String stationFrom,
    required String stationTo,
    String line = 'UP',
    String activity = 'Sleepers unloaded',
    double output = 0.0,
    String outputUnit = 'Nos',
    String remarks = '',
    bool isTransit = false,
  }) {
    return BlockEntry(
      id: id,
      startTime: startTime,
      endTime: endTime,
      stationFrom: stationFrom,
      stationTo: stationTo,
      line: line,
      items: [
        WorkItem(
          activity: activity,
          output: output,
          outputUnit: outputUnit,
        ),
      ],
      remarks: remarks,
      isTransit: isTransit,
    );
  }

  // Backward compatibility getters
  String get activity => items.isNotEmpty ? items.first.activity : '';
  double get output => items.fold(0.0, (sum, i) => sum + i.output);
  String get outputUnit => items.isNotEmpty ? items.first.outputUnit : 'Nos';

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime,
    'endTime': endTime,
    'stationFrom': stationFrom,
    'stationTo': stationTo,
    'line': line,
    'items': items.map((i) => i.toJson()).toList(),
    'activity': activity,
    'output': output,
    'outputUnit': outputUnit,
    'remarks': remarks,
    'isTransit': isTransit,
  };

  factory BlockEntry.fromJson(Map<String, dynamic> json) {
    List<WorkItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['activity'] != null) {
      parsedItems = [
        WorkItem(
          activity: json['activity'] as String? ?? 'Sleepers unloaded',
          output: (json['output'] as num?)?.toDouble() ?? 0.0,
          outputUnit: json['outputUnit'] as String? ?? 'Nos',
        ),
      ];
    }

    return BlockEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      stationFrom: json['stationFrom'] as String? ?? '',
      stationTo: json['stationTo'] as String? ?? '',
      line: json['line'] as String? ?? 'UP',
      items: parsedItems,
      remarks: json['remarks'] as String? ?? '',
      isTransit: json['isTransit'] as bool? ?? false,
    );
  }

  BlockEntry copyWith({
    String? id,
    String? startTime,
    String? endTime,
    String? stationFrom,
    String? stationTo,
    String? line,
    List<WorkItem>? items,
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
      items: items ?? this.items,
      remarks: remarks ?? this.remarks,
      isTransit: isTransit ?? this.isTransit,
    );
  }
}
