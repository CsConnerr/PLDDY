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

class PlannerRequest {
  final ActivityType activity;
  final int durationMinutes;

  const PlannerRequest({
    required this.activity,
    required this.durationMinutes,
  });
}

class PlannedActivity {
  final ActivityType activity;
  final int durationMinutes;
  final PlannerSuggestion suggestion;

  const PlannedActivity({
    required this.activity,
    required this.durationMinutes,
    required this.suggestion,
  });
}

class SmartPlanner {
  static const int defaultDayStartHour = 7;
  static const int defaultDayEndHour = 23;

  static List<PlannerSuggestion> suggest({
    required DateTime day,
    required List<ScheduleBlock> busyBlocks,
    required int durationMinutes,
    required ActivityType activity,
    int maxSuggestions = 4,
    int transitionBufferMinutes = 15,
    int dayStartHour = defaultDayStartHour,
    int dayEndHour = defaultDayEndHour,
    DateTime? now,
  }) {
    if (durationMinutes <= 0 || maxSuggestions <= 0) {
      return <PlannerSuggestion>[];
    }

    final DateTime currentTime = now ?? DateTime.now();
    final DateTime dayStart = DateTime(
      day.year,
      day.month,
      day.day,
      dayStartHour,
    );
    final DateTime dayEnd = DateTime(
      day.year,
      day.month,
      day.day,
      dayEndHour,
    );

    if (!dayStart.isBefore(dayEnd)) {
      return <PlannerSuggestion>[];
    }

    DateTime earliestStart = dayStart;
    if (_isSameDay(day, currentTime)) {
      earliestStart = _roundUpToQuarterHour(
        currentTime.add(const Duration(minutes: 10)),
      );
      if (earliestStart.isBefore(dayStart)) {
        earliestStart = dayStart;
      }
    } else if (_dayOnly(day).isBefore(_dayOnly(currentTime))) {
      return <PlannerSuggestion>[];
    }

    if (!earliestStart.isBefore(dayEnd)) {
      return <PlannerSuggestion>[];
    }

    final List<ScheduleBlock> bufferedBlocks = _mergeBlocks(
      busyBlocks
          .where(
            (ScheduleBlock block) =>
                block.start.isBefore(dayEnd) && block.end.isAfter(dayStart),
          )
          .map(
            (ScheduleBlock block) => ScheduleBlock(
              start: block.start
                  .subtract(Duration(minutes: transitionBufferMinutes)),
              end: block.end.add(Duration(minutes: transitionBufferMinutes)),
            ),
          )
          .toList(),
    );

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

  static List<PlannedActivity> planDay({
    required DateTime day,
    required List<ScheduleBlock> busyBlocks,
    required List<PlannerRequest> requests,
    int transitionBufferMinutes = 15,
    int dayStartHour = defaultDayStartHour,
    int dayEndHour = defaultDayEndHour,
    DateTime? now,
  }) {
    final List<ScheduleBlock> workingBusy = List<ScheduleBlock>.from(busyBlocks);
    final List<PlannerRequest> pending = requests
        .where((PlannerRequest request) => request.durationMinutes > 0)
        .toList();
    final List<PlannedActivity> planned = <PlannedActivity>[];

    while (pending.isNotEmpty) {
      PlannerRequest? requestToPlace;
      List<PlannerSuggestion> bestOptions = <PlannerSuggestion>[];
      int fewestOptions = 1 << 30;

      for (final PlannerRequest request in pending) {
        final List<PlannerSuggestion> options = suggest(
          day: day,
          busyBlocks: workingBusy,
          durationMinutes: request.durationMinutes,
          activity: request.activity,
          maxSuggestions: 8,
          transitionBufferMinutes: transitionBufferMinutes,
          dayStartHour: dayStartHour,
          dayEndHour: dayEndHour,
          now: now,
        );

        if (options.isEmpty) {
          continue;
        }

        final bool isMoreConstrained = options.length < fewestOptions;
        final bool sameConstraintButLonger =
            options.length == fewestOptions &&
                requestToPlace != null &&
                request.durationMinutes > requestToPlace.durationMinutes;

        if (requestToPlace == null ||
            isMoreConstrained ||
            sameConstraintButLonger) {
          requestToPlace = request;
          bestOptions = options;
          fewestOptions = options.length;
        }
      }

      if (requestToPlace == null || bestOptions.isEmpty) {
        break;
      }

      final PlannerSuggestion chosen = bestOptions.first;
      planned.add(
        PlannedActivity(
          activity: requestToPlace.activity,
          durationMinutes: requestToPlace.durationMinutes,
          suggestion: chosen,
        ),
      );
      workingBusy.add(
        ScheduleBlock(start: chosen.start, end: chosen.end),
      );
      pending.remove(requestToPlace);
    }

    planned.sort(
      (PlannedActivity a, PlannedActivity b) =>
          a.suggestion.start.compareTo(b.suggestion.start),
    );
    return planned;
  }

  static int availableMinutes({
    required DateTime day,
    required List<ScheduleBlock> busyBlocks,
    int dayStartHour = defaultDayStartHour,
    int dayEndHour = defaultDayEndHour,
    DateTime? now,
  }) {
    final DateTime currentTime = now ?? DateTime.now();
    final DateTime dayStart = DateTime(
      day.year,
      day.month,
      day.day,
      dayStartHour,
    );
    final DateTime dayEnd = DateTime(
      day.year,
      day.month,
      day.day,
      dayEndHour,
    );

    if (_dayOnly(day).isBefore(_dayOnly(currentTime))) {
      return 0;
    }

    DateTime windowStart = dayStart;
    if (_isSameDay(day, currentTime) && currentTime.isAfter(windowStart)) {
      windowStart = currentTime.isAfter(dayEnd) ? dayEnd : currentTime;
    }

    if (!windowStart.isBefore(dayEnd)) {
      return 0;
    }

    final List<ScheduleBlock> clipped = busyBlocks
        .where(
          (ScheduleBlock block) =>
              block.start.isBefore(dayEnd) && block.end.isAfter(windowStart),
        )
        .map(
          (ScheduleBlock block) => ScheduleBlock(
            start: block.start.isBefore(windowStart) ? windowStart : block.start,
            end: block.end.isAfter(dayEnd) ? dayEnd : block.end,
          ),
        )
        .toList();

    final List<ScheduleBlock> merged = _mergeBlocks(clipped);
    final int busyMinutes = merged.fold<int>(
      0,
      (int total, ScheduleBlock block) =>
          total + block.end.difference(block.start).inMinutes,
    );
    final int totalMinutes = dayEnd.difference(windowStart).inMinutes;
    final int available = totalMinutes - busyMinutes;
    return available < 0 ? 0 : available;
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
      score += breathingRoom.clamp(0, 180).toDouble() * 1.2;
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
    } else if (activity == ActivityType.workout && start.hour >= 21) {
      score -= 150;
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

  static List<ScheduleBlock> _mergeBlocks(List<ScheduleBlock> blocks) {
    if (blocks.isEmpty) {
      return <ScheduleBlock>[];
    }

    final List<ScheduleBlock> sorted = List<ScheduleBlock>.from(blocks)
      ..sort(
        (ScheduleBlock a, ScheduleBlock b) => a.start.compareTo(b.start),
      );
    final List<ScheduleBlock> merged = <ScheduleBlock>[sorted.first];

    for (int index = 1; index < sorted.length; index++) {
      final ScheduleBlock current = sorted[index];
      final ScheduleBlock previous = merged.last;
      if (!current.start.isAfter(previous.end)) {
        final DateTime laterEnd =
            current.end.isAfter(previous.end) ? current.end : previous.end;
        merged[merged.length - 1] = ScheduleBlock(
          start: previous.start,
          end: laterEnd,
        );
      } else {
        merged.add(current);
      }
    }

    return merged;
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

  static DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
