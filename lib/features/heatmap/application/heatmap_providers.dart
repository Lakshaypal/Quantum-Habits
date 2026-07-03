import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Map of day → [DayStat], derived purely from habits + entries in the cache.
final dayStatsProvider = Provider<Map<DateTime, DayStat>>((ref) {
  final habits = ref.watch(activeHabitsProvider).asData?.value ?? const [];
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const [];
  final active = habits.length;

  final completedByDay = <DateTime, int>{};
  for (final e in entries) {
    if (e.completed) {
      final k = dayKey(e.date);
      completedByDay[k] = (completedByDay[k] ?? 0) + 1;
    }
  }
  return {
    for (final entry in completedByDay.entries)
      entry.key: DayStat(
          entry.key, entry.value, active, levelFor(entry.value, active)),
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
  final success = <DateTime>{
    for (final s in stats.values)
      if (s.level >= 1) s.day,
  };
  if (success.isEmpty) return const StreakStats(0, 0, 0);

  final sorted = success.toList()..sort();
  int longest = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }

  final today = dayKey(DateTime.now());
  var cursor = success.contains(today) ? today : today.subtract(const Duration(days: 1));
  int current = 0;
  while (success.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  int last30 = 0;
  for (int i = 0; i < 30; i++) {
    if (success.contains(today.subtract(Duration(days: i)))) last30++;
  }
  return StreakStats(current, longest, last30 / 30);
});
