class ReminderItem {
  final String id;
  final String text;
  final bool isDone;

  const ReminderItem({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isDone': isDone,
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    text: json['text'] as String? ?? '',
    isDone: json['isDone'] as bool? ?? false,
  );

  ReminderItem copyWith({
    String? id,
    String? text,
    bool? isDone,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }
}
