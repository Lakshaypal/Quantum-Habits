import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_schedule.dart';

/// Aggregate completion for a single day, resolved to a heatmap level 0–4.
class DayStat {
  final DateTime day;
  final int completed;
  final int active;
  final int level;
  const DayStat(this.day, this.completed, this.active, this.level);
}

/// 0 none · 1 low · 2 moderate · 3 high · 4 perfect (all active habits done).
int levelFor(int completed, int active) {
  if (completed <= 0 || active <= 0) return 0;
  final ratio = completed / active;
  if (ratio >= 1.0) return 4;
  if (ratio >= 0.67) return 3;
  if (ratio >= 0.34) return 2;
  return 1;
}

/// Whether [h] existed on [day]: created on or before it and not yet
/// soft-deleted. Archived habits still count for days before today, so
/// archiving (or adding new habits) never rewrites past heatmap levels.
bool habitAliveOn(Habit h, DateTime day, DateTime today) {
  if (dayKey(h.createdAt).isAfter(day)) return false;
  final deleted = h.deletedAt;
  if (deleted != null && !dayKey(deleted).isAfter(day)) return false;
  if (h.archived && !day.isBefore(today)) return false;
  return true;
}

/// Habits that were *due* on [day] — alive and, per their schedule, expected
/// that day (daily always; weekday habits only on their weekdays; times-per-
/// week habits never count as a per-day obligation). Missing a due habit is a
/// genuine miss; missing a not-due one is not.
int expectedCountOn(List<Habit> habits, DateTime day, DateTime today) => habits
    .where((h) =>
        habitAliveOn(h, day, today) && scheduleOf(h).countsTowardMissOn(day))
    .length;

/// Map of day → [DayStat]. Each day is scored against the habits that were
/// due that day (history is immutable). The denominator is `max(due, done)`,
/// so extra effort on a rest day still lights the square green and a
/// weekday-only habit never dims the weekend.
final dayStatsProvider = Provider<Map<DateTime, DayStat>>((ref) {
  final habits = ref.watch(allHabitsAnyProvider).asData?.value ?? const [];
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const [];
  final today = ref.watch(currentDayProvider);
  final byId = {for (final h in habits) h.id: h};

  final completedByDay = <DateTime, int>{};
  for (final e in entries) {
    if (!e.completed) continue;
    final habit = byId[e.habitId];
    final k = dayKey(e.date);
    // Orphan or out-of-lifetime entries don't inflate the numerator.
    if (habit == null || !habitAliveOn(habit, k, today)) continue;
    completedByDay[k] = (completedByDay[k] ?? 0) + 1;
  }

  final expectedCache = <DateTime, int>{};
  int expectedOn(DateTime day) => expectedCache.putIfAbsent(
      day, () => expectedCountOn(habits, day, today));

  return {
    for (final entry in completedByDay.entries)
      entry.key: () {
        final done = entry.value;
        final denom = math.max(expectedOn(entry.key), done);
        return DayStat(entry.key, done, denom, levelFor(done, denom));
      }(),
  };
});

class StreakStats {
  final int current;
  final int longest;
  final double monthlyConsistency; // 0..1 over trailing 30 days
  const StreakStats(this.current, this.longest, this.monthlyConsistency);
}

/// Subtle, schedule-aware streak math. A "successful day" is any day with at
/// least one completion (level >= 1). Rest days — days on which nothing was
/// due — neither break nor extend a streak, so a Mon–Fri habit keeps its
/// streak across the weekend. A due day with no completion is the only thing
/// that breaks it.
final streakStatsProvider = Provider<StreakStats>((ref) {
  final stats = ref.watch(dayStatsProvider);
  final habits = ref.watch(allHabitsAnyProvider).asData?.value ?? const [];
  final today = ref.watch(currentDayProvider);
  final success = <DateTime>{
    for (final s in stats.values)
      if (s.level >= 1) s.day,
  };
  if (success.isEmpty) return const StreakStats(0, 0, 0);

  final expectedCache = <DateTime, int>{};
  bool isRest(DateTime d) => expectedCache.putIfAbsent(
          d, () => expectedCountOn(habits, d, today)) ==
      0;

  // Longest: sweep every day from the first success to today so rest days
  // bridge instead of reset.
  final earliest = success.reduce((a, b) => a.isBefore(b) ? a : b);
  int longest = 0, run = 0;
  for (var d = earliest; !d.isAfter(today); d = addDays(d, 1)) {
    if (success.contains(d)) {
      run++;
      if (run > longest) longest = run;
    } else if (!isRest(d)) {
      run = 0;
    }
  }

  // Current: walk back from today, skipping rest days. Today not-yet-done
  // doesn't break the streak; a past due-but-empty day does.
  int current = 0;
  var cursor = today;
  var guard = 0;
  while (guard++ < 3000 && !cursor.isBefore(earliest)) {
    if (success.contains(cursor)) {
      current++;
    } else if (!isRest(cursor) && cursor != today) {
      break;
    }
    cursor = addDays(cursor, -1);
  }

  // 30-day consistency: honored due-days ÷ due-days (rest days excluded).
  int due = 0, hit = 0;
  for (int i = 0; i < 30; i++) {
    final d = addDays(today, -i);
    if (isRest(d)) continue;
    due++;
    if (success.contains(d)) hit++;
  }
  return StreakStats(current, longest, due == 0 ? 0 : hit / due);
});
