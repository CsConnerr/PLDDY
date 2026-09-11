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

    test('builds a day plan without overlapping planned activities', () {
      final DateTime day = DateTime(2026, 9, 10);
      final List<PlannedActivity> plan = SmartPlanner.planDay(
        day: day,
        now: DateTime(2026, 9, 9, 12),
        busyBlocks: <ScheduleBlock>[
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 11),
            end: DateTime(2026, 9, 10, 13),
          ),
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 17),
            end: DateTime(2026, 9, 10, 18),
          ),
        ],
        requests: const <PlannerRequest>[
          PlannerRequest(activity: ActivityType.study, durationMinutes: 90),
          PlannerRequest(activity: ActivityType.homework, durationMinutes: 60),
          PlannerRequest(activity: ActivityType.workout, durationMinutes: 45),
        ],
      );

      expect(plan.length, 3);
      for (int first = 0; first < plan.length; first++) {
        for (int second = first + 1; second < plan.length; second++) {
          final PlannerSuggestion a = plan[first].suggestion;
          final PlannerSuggestion b = plan[second].suggestion;
          final bool overlaps = a.start.isBefore(b.end) && a.end.isAfter(b.start);
          expect(overlaps, isFalse);
        }
      }
    });

    test('available minutes merges overlapping commitments', () {
      final DateTime day = DateTime(2026, 9, 10);
      final int available = SmartPlanner.availableMinutes(
        day: day,
        now: DateTime(2026, 9, 9, 12),
        busyBlocks: <ScheduleBlock>[
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 9),
            end: DateTime(2026, 9, 10, 11),
          ),
          ScheduleBlock(
            start: DateTime(2026, 9, 10, 10),
            end: DateTime(2026, 9, 10, 12),
          ),
        ],
      );

      // The planning day is 16 hours long. The two commitments overlap and
      // occupy only three unique hours, leaving thirteen hours open.
      expect(available, 13 * 60);
    });
  });
}
