import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
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

  final today = dayKey(DateTime.now());
  final start = today.subtract(Duration(days: period.days - 1));
  final active = habits.length;

  bool inWindow(DateTime d) {
    final k = dayKey(d);
    return !k.isBefore(start) && !k.isAfter(today);
  }

  final perHabit = <String, int>{};
  final completedByDay = <DateTime, int>{};
  int totalCompletions = 0;
  for (final e in entries) {
    if (!e.completed || !inWindow(e.date)) continue;
    totalCompletions++;
    perHabit[e.habitId] = (perHabit[e.habitId] ?? 0) + 1;
    final k = dayKey(e.date);
    completedByDay[k] = (completedByDay[k] ?? 0) + 1;
  }

  final activeDays = completedByDay.length;
  final perfectDays =
      active == 0 ? 0 : completedByDay.values.where((c) => c >= active).length;
  final completionPct =
      active == 0 ? 0.0 : (totalCompletions / (active * period.days)).clamp(0.0, 1.0);
  final consistency = ((activeDays / period.days) * 100).round();

  final byId = {for (final h in habits) h.id: h};
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
