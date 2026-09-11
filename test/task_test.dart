import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plddy/task.dart';

void main() {
  group('Task', () {
    test('loads legacy saved task data safely', () {
      final Task task = Task.fromMap(<String, dynamic>{
        'time': <String, int>{'hour': 14, 'minute': 30},
        'description': 'Doctor appointment',
        'date': <String, int>{'year': 2026, 'month': 9, 'day': 10},
      });

      expect(task.time, const TimeOfDay(hour: 14, minute: 30));
      expect(task.description, 'Doctor appointment');
      expect(task.durationMinutes, 60);
      expect(task.category, TaskCategory.personal);
      expect(task.completed, isFalse);
      expect(task.suggestedByPlddy, isFalse);
    });

    test('preserves new task metadata when serialized', () {
      final Task original = Task(
        id: 'task-1',
        time: const TimeOfDay(hour: 9, minute: 15),
        description: 'Study',
        date: DateTime(2026, 9, 10),
        durationMinutes: 90,
        category: TaskCategory.study,
        completed: true,
        suggestedByPlddy: true,
      );

      final Task restored = Task.fromMap(original.toMap());

      expect(restored.id, 'task-1');
      expect(restored.durationMinutes, 90);
      expect(restored.category, TaskCategory.study);
      expect(restored.completed, isTrue);
      expect(restored.suggestedByPlddy, isTrue);
    });
  });
}
