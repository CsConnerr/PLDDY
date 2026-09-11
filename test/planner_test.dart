import 'package:flutter_test/flutter_test.dart';
import 'package:plddy/planner.dart';

void main() {
  group('SmartPlanner', () {
    test('does not suggest time that overlaps a commitment and its buffer', () {
      final DateTime day = DateTime(2026, 9, 10);
      final List<PlannerSuggestion> suggestions = SmartPlanner.suggest(
        day: day,
        now: DateTime(2026, 9, 9, 12),
        durationMinutes: 60,
        activity: ActivityType.study,
        busyBlocks: <ScheduleBlock>[
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 13),
            end: DateTime(2026, 9, 10, 14),
          ),
        ],
      );

      for (final PlannerSuggestion suggestion in suggestions) {
        expect(
          suggestion.end.isAfter(DateTime(2026, 9, 10, 12, 45)) &&
              suggestion.start.isBefore(DateTime(2026, 9, 10, 14, 15)),
          isFalse,
        );
      }
    });

    test('does not suggest a time that has already passed today', () {
      final DateTime day = DateTime(2026, 9, 10);
      final List<PlannerSuggestion> suggestions = SmartPlanner.suggest(
        day: day,
        now: DateTime(2026, 9, 10, 15, 7),
        durationMinutes: 60,
        activity: ActivityType.homework,
        busyBlocks: const <ScheduleBlock>[],
      );

      expect(suggestions, isNotEmpty);
      for (final PlannerSuggestion suggestion in suggestions) {
        expect(
          suggestion.start.isBefore(DateTime(2026, 9, 10, 15, 30)),
          isFalse,
        );
      }
    });

    test('returns no suggestion when the day is fully occupied', () {
      final DateTime day = DateTime(2026, 9, 10);
      final List<PlannerSuggestion> suggestions = SmartPlanner.suggest(
        day: day,
        now: DateTime(2026, 9, 9, 12),
        durationMinutes: 60,
        activity: ActivityType.workout,
        busyBlocks: <ScheduleBlock>[
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 6),
            end: DateTime(2026, 9, 10, 23, 30),
          ),
        ],
      );

      expect(suggestions, isEmpty);
    });
  });
}
