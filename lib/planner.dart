enum ActivityType { study, homework, workout }

class ScheduleBlock {
  final DateTime start;
  final DateTime end;

  const ScheduleBlock({required this.start, required this.end});
}

class PlannerSuggestion {
  final DateTime start;
  final DateTime end;
  final double score;

  const PlannerSuggestion({
    required this.start,
    required this.end,
    required this.score,
  });
}

class SmartPlanner {
  static List<PlannerSuggestion> suggest({
    required DateTime day,
    required List<ScheduleBlock> busyBlocks,
    required int durationMinutes,
    required ActivityType activity,
    int maxSuggestions = 4,
    int transitionBufferMinutes = 15,
    DateTime? now,
  }) {
    final DateTime currentTime = now ?? DateTime.now();
    final DateTime dayStart = DateTime(day.year, day.month, day.day, 7);
    final DateTime dayEnd = DateTime(day.year, day.month, day.day, 23);

    DateTime earliestStart = dayStart;
    if (_isSameDay(day, currentTime)) {
      earliestStart = _roundUpToQuarterHour(
        currentTime.add(const Duration(minutes: 10)),
      );
      if (earliestStart.isBefore(dayStart)) {
        earliestStart = dayStart;
      }
    }

    if (!earliestStart.isBefore(dayEnd)) {
      return <PlannerSuggestion>[];
    }

    final List<ScheduleBlock> bufferedBlocks = busyBlocks
        .where((ScheduleBlock block) =>
            block.start.isBefore(dayEnd) && block.end.isAfter(dayStart))
        .map(
          (ScheduleBlock block) => ScheduleBlock(
            start: block.start.subtract(
              Duration(minutes: transitionBufferMinutes),
            ),
            end: block.end.add(
              Duration(minutes: transitionBufferMinutes),
            ),
          ),
        )
        .toList()
      ..sort((ScheduleBlock a, ScheduleBlock b) =>
          a.start.compareTo(b.start));

    final List<PlannerSuggestion> candidates = <PlannerSuggestion>[];
    DateTime candidateStart = earliestStart;

    while (!candidateStart
        .add(Duration(minutes: durationMinutes))
        .isAfter(dayEnd)) {
      final DateTime candidateEnd =
          candidateStart.add(Duration(minutes: durationMinutes));

      final bool overlaps = bufferedBlocks.any(
        (ScheduleBlock block) =>
            candidateStart.isBefore(block.end) &&
            candidateEnd.isAfter(block.start),
      );

      if (!overlaps) {
        candidates.add(
          PlannerSuggestion(
            start: candidateStart,
            end: candidateEnd,
            score: _scoreCandidate(
              start: candidateStart,
              end: candidateEnd,
              dayStart: dayStart,
              dayEnd: dayEnd,
              busyBlocks: bufferedBlocks,
              activity: activity,
            ),
          ),
        );
      }

      candidateStart = candidateStart.add(const Duration(minutes: 15));
    }

    candidates.sort(
      (PlannerSuggestion a, PlannerSuggestion b) =>
          b.score.compareTo(a.score),
    );

    final List<PlannerSuggestion> selected = <PlannerSuggestion>[];
    for (final PlannerSuggestion suggestion in candidates) {
      final bool tooClose = selected.any(
        (PlannerSuggestion existing) =>
            suggestion.start.difference(existing.start).inMinutes.abs() < 45,
      );
      if (!tooClose) {
        selected.add(suggestion);
      }
      if (selected.length == maxSuggestions) {
        break;
      }
    }

    if (selected.length < maxSuggestions) {
      for (final PlannerSuggestion suggestion in candidates) {
        if (!selected.contains(suggestion)) {
          selected.add(suggestion);
        }
        if (selected.length == maxSuggestions) {
          break;
        }
      }
    }

    return selected;
  }

  static double _scoreCandidate({
    required DateTime start,
    required DateTime end,
    required DateTime dayStart,
    required DateTime dayEnd,
    required List<ScheduleBlock> busyBlocks,
    required ActivityType activity,
  }) {
    double score = 0;
    final int startMinutes = start.hour * 60 + start.minute;
    final List<int> preferredTimes = _preferredMinutes(activity);

    int closestPreference = 24 * 60;
    for (final int preferred in preferredTimes) {
      final int distance = (startMinutes - preferred).abs();
      if (distance < closestPreference) {
        closestPreference = distance;
      }
    }
    score += 1000 - closestPreference.toDouble();

    DateTime freeWindowStart = dayStart;
    DateTime freeWindowEnd = dayEnd;

    for (final ScheduleBlock block in busyBlocks) {
      if (!block.end.isAfter(start) && block.end.isAfter(freeWindowStart)) {
        freeWindowStart = block.end;
      }
      if (!block.start.isBefore(end) && block.start.isBefore(freeWindowEnd)) {
        freeWindowEnd = block.start;
      }
    }

    final int freeWindowMinutes =
        freeWindowEnd.difference(freeWindowStart).inMinutes;
    final int taskMinutes = end.difference(start).inMinutes;
    final int breathingRoom = freeWindowMinutes - taskMinutes;
    if (breathingRoom > 0) {
      score += breathingRoom.clamp(0, 180) * 1.2;
    }

    if (start.minute == 0 || start.minute == 30) {
      score += 20;
    }

    if (activity == ActivityType.study || activity == ActivityType.homework) {
      if (start.hour >= 21) {
        score -= 250;
      }
      if (start.hour < 8) {
        score -= 100;
      }
    } else if (activity == ActivityType.workout) {
      if (start.hour >= 21) {
        score -= 150;
      }
    }

    score -= start.difference(dayStart).inMinutes * 0.02;
    return score;
  }

  static List<int> _preferredMinutes(ActivityType activity) {
    switch (activity) {
      case ActivityType.study:
        return <int>[9 * 60 + 30, 13 * 60 + 30, 16 * 60 + 30, 19 * 60];
      case ActivityType.homework:
        return <int>[10 * 60, 14 * 60, 17 * 60, 19 * 60 + 30];
      case ActivityType.workout:
        return <int>[8 * 60, 12 * 60 + 30, 17 * 60 + 30, 19 * 60];
    }
  }

  static DateTime _roundUpToQuarterHour(DateTime value) {
    final DateTime minuteStart = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
    final int remainder = minuteStart.minute % 15;
    if (remainder == 0) {
      return minuteStart;
    }
    return minuteStart.add(Duration(minutes: 15 - remainder));
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
