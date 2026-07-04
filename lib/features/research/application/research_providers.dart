import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_type.dart';
import '../../heatmap/application/heatmap_providers.dart';
import '../data/research_templates.dart';

/// Active habits tagged as research metrics. Matching is trimmed and
/// case-insensitive so 'research', 'RESEARCH ' etc. all land on the dashboard.
final researchHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(activeHabitsProvider).asData?.value ?? const [];
  final wanted = kResearchCategory.toLowerCase();
  return habits
      .where((h) => (h.category ?? '').trim().toLowerCase() == wanted)
      .toList();
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

/// Deterministic habit id for a template, identical on every device — the
/// key to seeding never duplicating across installs.
String researchTemplateId(String name) =>
    'research-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

/// Creates the preset research metrics as habits. Truly idempotent: ids are
/// deterministic, existence is checked against the database (not a possibly
/// stale provider snapshot), and re-running (or running on a second device)
/// converges to a single copy of each metric after sync.
final researchSetupProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final db = ref.read(databaseProvider);
    final service = ref.read(habitServiceProvider);
    final existing = (await db.allHabits())
        .where((h) => h.deletedAt == null)
        .map((h) => h.id)
        .toSet();
    for (final tpl in kResearchTemplates) {
      final id = researchTemplateId(tpl.name);
      if (existing.contains(id)) continue;
      await service.addHabit(
        id: id,
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

/// One-shot repair for installs that seeded templates with random ids on
/// multiple devices: among live Research habits sharing a template name,
/// keeps the oldest (deterministic across devices) and soft-deletes the
/// rest — history is preserved and the same winner is chosen everywhere,
/// so sync converges instead of multiplying.
Future<void> dedupeResearchTemplates(AppDatabase db) async {
  final templateNames =
      kResearchTemplates.map((t) => t.name.toLowerCase()).toSet();
  final habits = (await db.allHabits())
      .where((h) =>
          h.deletedAt == null &&
          (h.category ?? '').trim().toLowerCase() ==
              kResearchCategory.toLowerCase() &&
          templateNames.contains(h.name.trim().toLowerCase()))
      .toList();
  final byName = <String, List<Habit>>{};
  for (final h in habits) {
    byName.putIfAbsent(h.name.trim().toLowerCase(), () => []).add(h);
  }
  for (final group in byName.values.where((g) => g.length > 1)) {
    group.sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
    });
    for (final loser in group.skip(1)) {
      await db.deleteHabit(loser.id, DateTime.now());
    }
  }
}
