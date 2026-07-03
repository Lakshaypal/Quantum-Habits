import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_type.dart';
import '../../heatmap/application/heatmap_providers.dart';
import '../data/research_templates.dart';

/// Active habits tagged as research metrics.
final researchHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(activeHabitsProvider).asData?.value ?? const [];
  return habits.where((h) => h.category == kResearchCategory).toList();
});

/// Aggregated totals for one research metric.
class MetricTotal {
  final Habit habit;
  final double total; // all-time sum of logged value
  final double week; // sum since start of this week
  final int activeDays; // days with a completion
  const MetricTotal(this.habit, this.total, this.week, this.activeDays);
}

final researchMetricsProvider = Provider<List<MetricTotal>>((ref) {
  final habits = ref.watch(researchHabitsProvider);
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const [];
  final weekStart = startOfWeek(DateTime.now());

  final byHabit = <String, List<HabitEntry>>{};
  for (final e in entries) {
    (byHabit[e.habitId] ??= []).add(e);
  }
  return [
    for (final h in habits)
      () {
        final es = byHabit[h.id] ?? const [];
        double total = 0, week = 0;
        int days = 0;
        for (final e in es) {
          // Binary habits sum as "1 per completed day"; others sum their value.
          final v = HabitTypeX.fromIndex(h.type) == HabitType.binary
              ? (e.completed ? 1.0 : 0.0)
              : e.value;
          total += v;
          if (!dayKey(e.date).isBefore(weekStart)) week += v;
          if (e.completed) days++;
        }
        return MetricTotal(h, total, week, days);
      }()
  ];
});

/// Heatmap intensity computed from research metrics only — "the same heatmap,"
/// focused on the technical workflow.
final researchDayStatsProvider = Provider<Map<DateTime, DayStat>>((ref) {
  final habits = ref.watch(researchHabitsProvider);
  final ids = habits.map((h) => h.id).toSet();
  final active = habits.length;
  final entries = (ref.watch(allEntriesProvider).asData?.value ?? const [])
      .where((e) => ids.contains(e.habitId));

  final byDay = <DateTime, int>{};
  for (final e in entries) {
    if (e.completed) {
      final k = dayKey(e.date);
      byDay[k] = (byDay[k] ?? 0) + 1;
    }
  }
  return {
    for (final entry in byDay.entries)
      entry.key: DayStat(entry.key, entry.value, active, levelFor(entry.value, active)),
  };
});

/// Creates the preset research metrics as habits (idempotent-ish: skips names
/// that already exist in the Research category).
final researchSetupProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(habitServiceProvider);
    final existing = ref.read(researchHabitsProvider).map((h) => h.name).toSet();
    for (final tpl in kResearchTemplates) {
      if (existing.contains(tpl.name)) continue;
      await service.addHabit(
        name: tpl.name,
        type: tpl.type,
        color: tpl.color,
        icon: tpl.icon,
        category: kResearchCategory,
        target: tpl.target,
        unit: tpl.unit,
      );
    }
  };
});
