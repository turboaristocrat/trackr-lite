enum MovementItemType {
  transit,
  stay,
  custom,
}

enum MovementFormatStyle {
  register, // Line-by-line split across calendar dates with braces (Image 2 style)
  dualDate, // Dual date on single line for night runs (WhatsApp / Telegram style)
}

class MovementRun {
  final String fromStation;
  final String toStation;
  final String departureTime; // "09:16" or "21:57"
  final String arrivalTime; // "16:36" or "04:20" or ""
  final bool isOvernight;
  final bool isArrivalLeg; // Morning arrival of overnight run
  final bool isDepartureLeg; // Night departure of overnight run

  const MovementRun({
    required this.fromStation,
    required this.toStation,
    required this.departureTime,
    required this.arrivalTime,
    this.isOvernight = false,
    this.isArrivalLeg = false,
    this.isDepartureLeg = false,
  });

  Map<String, dynamic> toJson() => {
    'fromStation': fromStation,
    'toStation': toStation,
    'departureTime': departureTime,
    'arrivalTime': arrivalTime,
    'isOvernight': isOvernight,
    'isArrivalLeg': isArrivalLeg,
    'isDepartureLeg': isDepartureLeg,
  };

  factory MovementRun.fromJson(Map<String, dynamic> json) => MovementRun(
    fromStation: json['fromStation'] as String? ?? '',
    toStation: json['toStation'] as String? ?? '',
    departureTime: json['departureTime'] as String? ?? '',
    arrivalTime: json['arrivalTime'] as String? ?? '',
    isOvernight: json['isOvernight'] as bool? ?? false,
    isArrivalLeg: json['isArrivalLeg'] as bool? ?? false,
    isDepartureLeg: json['isDepartureLeg'] as bool? ?? false,
  );

  MovementRun copyWith({
    String? fromStation,
    String? toStation,
    String? departureTime,
    String? arrivalTime,
    bool? isOvernight,
    bool? isArrivalLeg,
    bool? isDepartureLeg,
  }) {
    return MovementRun(
      fromStation: fromStation ?? this.fromStation,
      toStation: toStation ?? this.toStation,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isOvernight: isOvernight ?? this.isOvernight,
      isArrivalLeg: isArrivalLeg ?? this.isArrivalLeg,
      isDepartureLeg: isDepartureLeg ?? this.isDepartureLeg,
    );
  }
}

class MovementDayItem {
  final String date; // YYYY-MM-DD
  final MovementItemType type;
  final List<MovementRun> runs;
  final String stayStation;
  final String customText;
  final bool isManualOverride;

  const MovementDayItem({
    required this.date,
    required this.type,
    this.runs = const [],
    this.stayStation = '',
    this.customText = '',
    this.isManualOverride = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'type': type.name,
    'runs': runs.map((r) => r.toJson()).toList(),
    'stayStation': stayStation,
    'customText': customText,
    'isManualOverride': isManualOverride,
  };

  factory MovementDayItem.fromJson(Map<String, dynamic> json) => MovementDayItem(
    date: json['date'] as String,
    type: MovementItemType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MovementItemType.stay,
    ),
    runs: (json['runs'] as List<dynamic>?)
            ?.map((e) => MovementRun.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    stayStation: json['stayStation'] as String? ?? '',
    customText: json['customText'] as String? ?? '',
    isManualOverride: json['isManualOverride'] as bool? ?? false,
  );

  MovementDayItem copyWith({
    String? date,
    MovementItemType? type,
    List<MovementRun>? runs,
    String? stayStation,
    String? customText,
    bool? isManualOverride,
  }) {
    return MovementDayItem(
      date: date ?? this.date,
      type: type ?? this.type,
      runs: runs ?? this.runs,
      stayStation: stayStation ?? this.stayStation,
      customText: customText ?? this.customText,
      isManualOverride: isManualOverride ?? this.isManualOverride,
    );
  }
}
