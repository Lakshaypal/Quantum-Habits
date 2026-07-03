import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';

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

/// Map of day → [DayStat]. Each day is scored against the habits that
/// actually existed on that day — history is immutable.
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

  final aliveCountCache = <DateTime, int>{};
  int aliveOn(DateTime day) => aliveCountCache.putIfAbsent(
      day,
      () =>
          habits.where((h) => habitAliveOn(h, day, today)).length);

  return {
    for (final entry in completedByDay.entries)
      entry.key: DayStat(entry.key, entry.value, aliveOn(entry.key),
          levelFor(entry.value, aliveOn(entry.key))),
  };
});

class StreakStats {
  final int current;
  final int longest;
  final double monthlyConsistency; // 0..1 over trailing 30 days
  const StreakStats(this.current, this.longest, this.monthlyConsistency);
}

/// Subtle streak math. A "successful day" is any day with at least one
/// completion (level >= 1) — supportive, not all-or-nothing.
final streakStatsProvider = Provider<StreakStats>((ref) {
  final stats = ref.watch(dayStatsProvider);
  final today = ref.watch(currentDayProvider);
  final success = <DateTime>{
    for (final s in stats.values)
      if (s.level >= 1) s.day,
  };
  if (success.isEmpty) return const StreakStats(0, 0, 0);

  final sorted = success.toList()..sort();
  int longest = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && daysBetween(prev, d) == 1) ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }

  var cursor = success.contains(today) ? today : addDays(today, -1);
  int current = 0;
  while (success.contains(cursor)) {
    current++;
    cursor = addDays(cursor, -1);
  }

  int last30 = 0;
  for (int i = 0; i < 30; i++) {
    if (success.contains(addDays(today, -i))) last30++;
  }
  return StreakStats(current, longest, last30 / 30);
});
