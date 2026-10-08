class ReminderItem {
  final String id;
  final String title;
  final String details;
  final String? reminderDate; // YYYY-MM-DD
  final String? reminderTime; // HH:mm
  final String category; // 'Maintenance', 'Fuel', 'Caution', 'Inspection', 'Handover', 'General'
  final List<String> tags;
  final bool isDone;
  final String createdAt;

  const ReminderItem({
    required this.id,
    String? title,
    String? text,
    this.details = '',
    this.reminderDate,
    this.reminderTime,
    this.category = 'General',
    this.tags = const [],
    this.isDone = false,
    this.createdAt = '',
  }) : title = title ?? text ?? '';

  // Backward compatibility getter
  String get text => title;

  bool get hasReminder =>
      (reminderDate != null && reminderDate!.isNotEmpty) ||
      (reminderTime != null && reminderTime!.isNotEmpty);

  String get reminderDisplay {
    if (!hasReminder) return '';
    final d = reminderDate ?? '';
    final t = reminderTime ?? '';
    if (d.isNotEmpty && t.isNotEmpty) return '$d at $t hrs';
    if (d.isNotEmpty) return d;
    return '$t hrs';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': title,
    'details': details,
    'reminderDate': reminderDate,
    'reminderTime': reminderTime,
    'category': category,
    'tags': tags,
    'isDone': isDone,
    'createdAt': createdAt,
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? json['text'] as String? ?? '',
    details: json['details'] as String? ?? '',
    reminderDate: json['reminderDate'] as String?,
    reminderTime: json['reminderTime'] as String?,
    category: json['category'] as String? ?? 'General',
    tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    isDone: json['isDone'] as bool? ?? false,
    createdAt: json['createdAt'] as String? ?? '',
  );

  ReminderItem copyWith({
    String? id,
    String? title,
    String? details,
    String? reminderDate,
    String? reminderTime,
    String? category,
    List<String>? tags,
    bool? isDone,
    String? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderTime: reminderTime ?? this.reminderTime,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
