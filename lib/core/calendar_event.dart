enum EventRecurrence { none, daily, weekly, monthly, yearly }

enum EventCategory { meeting, personal, work, health, social, other }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String description;
  final String location;
  final bool isAllDay;
  final EventCategory category;
  final EventRecurrence recurrence;
  final int reminderMinutes;
  final bool isCompleted;
  final String? externalId;
  final String source;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description = '',
    this.location = '',
    this.isAllDay = false,
    this.category = EventCategory.other,
    this.recurrence = EventRecurrence.none,
    this.reminderMinutes = 15,
    this.isCompleted = false,
    this.externalId,
    this.source = 'local',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'description': description,
    'location': location,
    'is_all_day': isAllDay ? 1 : 0,
    'category': category.name,
    'recurrence': recurrence.name,
    'reminder_minutes': reminderMinutes,
    'is_completed': isCompleted ? 1 : 0,
    'external_id': externalId,
    'source': source,
    'created_at': DateTime.now().toIso8601String(),
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) => CalendarEvent(
    id: map['id'] as String,
    title: map['title'] as String,
    startTime: DateTime.parse(map['start_time'] as String),
    endTime: DateTime.parse(map['end_time'] as String),
    description: (map['description'] as String?) ?? '',
    location: (map['location'] as String?) ?? '',
    isAllDay: (map['is_all_day'] as int?) == 1,
    category: EventCategory.values.firstWhere(
      (c) => c.name == map['category'],
      orElse: () => EventCategory.other,
    ),
    recurrence: EventRecurrence.values.firstWhere(
      (r) => r.name == map['recurrence'],
      orElse: () => EventRecurrence.none,
    ),
    reminderMinutes: (map['reminder_minutes'] as int?) ?? 15,
    isCompleted: (map['is_completed'] as int?) == 1,
    externalId: map['external_id'] as String?,
    source: (map['source'] as String?) ?? 'local',
  );

  CalendarEvent copyWith({
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? location,
    bool? isAllDay,
    EventCategory? category,
    EventRecurrence? recurrence,
    int? reminderMinutes,
    bool? isCompleted,
  }) => CalendarEvent(
    id: id,
    title: title ?? this.title,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    description: description ?? this.description,
    location: location ?? this.location,
    isAllDay: isAllDay ?? this.isAllDay,
    category: category ?? this.category,
    recurrence: recurrence ?? this.recurrence,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    isCompleted: isCompleted ?? this.isCompleted,
    externalId: externalId,
    source: source,
  );

  String get dateStr => '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
  String get startTimeStr => '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  String get endTimeStr => '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  String get displayDate => '${startTime.month}/${startTime.day}/${startTime.year}';
  String get displayTime => '$startTimeStr - $endTimeStr';
  bool get isToday { final now = DateTime.now(); return startTime.year == now.year && startTime.month == now.month && startTime.day == now.day; }
  bool get isUpcoming => startTime.isAfter(DateTime.now());
  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': startTime.toIso8601String(),
    'end': endTime.toIso8601String(),
    'description': description,
    'location': location,
    'isAllDay': isAllDay,
    'category': category.name,
    'reminderMinutes': reminderMinutes,
    'source': source,
  };
}
