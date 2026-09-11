import 'package:flutter/material.dart';

enum TaskCategory {
  classMeeting,
  appointment,
  work,
  personal,
  study,
  homework,
  workout,
}

class Task {
  final String id;
  final TimeOfDay time;
  final String description;
  final DateTime date;
  final int durationMinutes;
  final TaskCategory category;
  final bool completed;
  final bool suggestedByPlddy;

  Task({
    required this.time,
    required this.description,
    required this.date,
    this.durationMinutes = 60,
    this.category = TaskCategory.personal,
    this.completed = false,
    this.suggestedByPlddy = false,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  DateTime get endDateTime =>
      startDateTime.add(Duration(minutes: durationMinutes));

  Task copyWith({
    TimeOfDay? time,
    String? description,
    DateTime? date,
    int? durationMinutes,
    TaskCategory? category,
    bool? completed,
    bool? suggestedByPlddy,
  }) {
    return Task(
      id: id,
      time: time ?? this.time,
      description: description ?? this.description,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      suggestedByPlddy: suggestedByPlddy ?? this.suggestedByPlddy,
    );
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final TimeOfDay decodedTime = _decodeTime(map['time']);
    final DateTime decodedDate = _decodeDate(map['date']);
    final String decodedDescription = map['description']?.toString() ?? 'Task';
    final String fallbackId = <String>[
      decodedDate.millisecondsSinceEpoch.toString(),
      decodedTime.hour.toString(),
      decodedTime.minute.toString(),
      decodedDescription.hashCode.toString(),
    ].join('_');

    return Task(
      id: map['id']?.toString() ?? fallbackId,
      time: decodedTime,
      description: decodedDescription,
      date: decodedDate,
      durationMinutes: _decodeDuration(map['durationMinutes']),
      category: _decodeCategory(map['category']),
      completed: map['completed'] == true,
      suggestedByPlddy: map['suggestedByPlddy'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'time': <String, int>{'hour': time.hour, 'minute': time.minute},
      'description': description,
      'date': <String, int>{
        'year': date.year,
        'month': date.month,
        'day': date.day,
      },
      'durationMinutes': durationMinutes,
      'category': category.name,
      'completed': completed,
      'suggestedByPlddy': suggestedByPlddy,
    };
  }

  static TimeOfDay _decodeTime(dynamic value) {
    if (value is Map) {
      return TimeOfDay(
        hour: int.tryParse(value['hour'].toString()) ?? 9,
        minute: int.tryParse(value['minute'].toString()) ?? 0,
      );
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return TimeOfDay.fromDateTime(parsed);
      }
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  static DateTime _decodeDate(dynamic value) {
    if (value is Map) {
      final DateTime now = DateTime.now();
      return DateTime(
        int.tryParse(value['year'].toString()) ?? now.year,
        int.tryParse(value['month'].toString()) ?? now.month,
        int.tryParse(value['day'].toString()) ?? now.day,
      );
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static int _decodeDuration(dynamic value) {
    final int? parsed = int.tryParse(value?.toString() ?? '');
    return parsed == null || parsed <= 0 ? 60 : parsed;
  }

  static TaskCategory _decodeCategory(dynamic value) {
    final String raw = value?.toString() ?? '';
    for (final TaskCategory category in TaskCategory.values) {
      if (category.name == raw) {
        return category;
      }
    }
    return TaskCategory.personal;
  }
}
