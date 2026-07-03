import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../journal/application/journal_providers.dart';

enum ReviewPeriod { week, month, year }

extension ReviewPeriodX on ReviewPeriod {
  String get label => switch (this) {
        ReviewPeriod.week => 'Week',
        ReviewPeriod.month => 'Month',
        ReviewPeriod.year => 'Year',
      };
  int get days => switch (this) {
        ReviewPeriod.week => 7,
        ReviewPeriod.month => 30,
        ReviewPeriod.year => 365,
      };
}

class AnalyticsSummary {
  final ReviewPeriod period;
  final int days;
  final double completionPct; // 0..1: completions / (activeHabits * days)
  final int consistencyScore; // 0..100: % of days with >=1 completion
  final int activeDays; // days with >=1 completion
  final int perfectDays; // days where all active habits were completed
  final int journalCount; // entries created in window
  final List<({Habit habit, int count})> top; // most-completed habits
  final List<Habit> missed; // active habits with 0 completions
  const AnalyticsSummary({
    required this.period,
    required this.days,
    required this.completionPct,
    required this.consistencyScore,
    required this.activeDays,
    required this.perfectDays,
    required this.journalCount,
    required this.top,
    required this.missed,
  });
}

final analyticsProvider = Provider.family<AnalyticsSummary, ReviewPeriod>((ref, period) {
  final habits = ref.watch(activeHabitsProvider).asData?.value ?? const [];
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const [];
  final journals = ref.watch(journalEntriesProvider).asData?.value ?? const [];

  final today = ref.watch(currentDayProvider);
  final start = addDays(today, -(period.days - 1));
  final active = habits.length;
  final byId = {for (final h in habits) h.id: h};

  bool inWindow(DateTime d) {
    final k = dayKey(d);
    return !k.isBefore(start) && !k.isAfter(today);
  }

  final perHabit = <String, int>{};
  final completedByDay = <DateTime, int>{};
  int totalCompletions = 0;
  for (final e in entries) {
    // Entries from archived/deleted habits stay out of the numbers — the
    // denominator below only counts the current active roster.
    if (!e.completed || !inWindow(e.date) || !byId.containsKey(e.habitId)) {
      continue;
    }
    totalCompletions++;
    perHabit[e.habitId] = (perHabit[e.habitId] ?? 0) + 1;
    final k = dayKey(e.date);
    completedByDay[k] = (completedByDay[k] ?? 0) + 1;
  }

  final activeDays = completedByDay.length;
  final perfectDays =
      active == 0 ? 0 : completedByDay.values.where((c) => c >= active).length;

  // Pro-rated denominator: a habit created mid-window only owes the days it
  // existed, so a young roster isn't scored against a full 365-day year.
  int owedDays = 0;
  for (final h in habits) {
    final created = dayKey(h.createdAt);
    final from = created.isAfter(start) ? created : start;
    if (!from.isAfter(today)) owedDays += daysBetween(from, today) + 1;
  }
  final completionPct =
      owedDays == 0 ? 0.0 : (totalCompletions / owedDays).clamp(0.0, 1.0);
  final trackedDays = habits.isEmpty
      ? 0
      : math.min(
          period.days,
          daysBetween(
                  habits
                      .map((h) => dayKey(h.createdAt))
                      .reduce((a, b) => a.isBefore(b) ? a : b),
                  today) +
              1);
  final consistency =
      trackedDays == 0 ? 0 : ((activeDays / trackedDays) * 100).round();
  final top = (perHabit.entries.where((e) => byId.containsKey(e.key)).toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(3)
      .map((e) => (habit: byId[e.key]!, count: e.value))
      .toList();
  final missed = habits.where((h) => (perHabit[h.id] ?? 0) == 0).toList();

  final journalCount = journals.where((j) => inWindow(j.createdAt)).length;

  return AnalyticsSummary(
    period: period,
    days: period.days,
    completionPct: completionPct.toDouble(),
    consistencyScore: consistency,
    activeDays: activeDays,
    perfectDays: perfectDays,
    journalCount: journalCount,
    top: top,
    missed: missed,
  );
});
