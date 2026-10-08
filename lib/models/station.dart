class Station {
  final String code;
  final String name;
  final String section;
  final String division;

  const Station({
    required this.code,
    required this.name,
    required this.section,
    required this.division,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'section': section,
    'division': division,
  };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    section: json['section'] as String? ?? '',
    division: json['division'] as String? ?? 'TVC',
  );

  @override
  String toString() => '$code - $name';
}
