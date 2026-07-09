import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_schedule.dart';
import '../../heatmap/application/heatmap_providers.dart';
import '../../journal/application/journal_providers.dart';
import '../../journal/data/journal_mood.dart';

enum InsightTone { positive, neutral, warn }

class Insight {
  final IconData icon;
  final String text;
  final InsightTone tone;
  const Insight(this.icon, this.text, this.tone);
}

const _weekdayNames = [
  'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays',
  'Fridays', 'Saturdays', 'Sundays',
];

/// Derived, plain-language observations for the Review screen — the
/// "Researcher's Dashboard" turned on your own data: streak-at-risk nudges,
/// your strongest/weakest weekday, and habit-to-habit correlations. All pure
/// computation over the local cache, bounded to recent history.
final insightsProvider = Provider<List<Insight>>((ref) {
  final habits = ref.watch(allHabitsAnyProvider).asData?.value ?? const [];
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const [];
  final today = ref.watch(currentDayProvider);
  final active =
      habits.where((h) => h.deletedAt == null && !h.archived).toList();
  if (active.isEmpty) return const [];

  // habitId → set of days completed.
  final byHabit = <String, Set<DateTime>>{};
  for (final e in entries) {
    if (e.completed) (byHabit[e.habitId] ??= {}).add(dayKey(e.date));
  }

  final out = <Insight>[];

  // 1) Streak-at-risk: due today, not yet done, with a live run behind it.
  var nudges = 0;
  for (final h in active) {
    if (nudges >= 2) break;
    final sched = scheduleOf(h);
    if (!sched.isDueOn(today)) continue;
    final done = byHabit[h.id] ?? const <DateTime>{};
    if (done.contains(today)) continue;
    int run = 0;
    var cur = addDays(today, -1);
    var guard = 0;
    while (guard++ < 500) {
      if (!sched.countsTowardMissOn(cur)) {
        cur = addDays(cur, -1); // rest day — doesn't break the run
        continue;
      }
      if (done.contains(cur)) {
        run++;
        cur = addDays(cur, -1);
      } else {
        break;
      }
    }
    if (run >= 3) {
      out.add(Insight(
        Icons.local_fire_department_outlined,
        'Your $run-day ${h.name} streak is on the line — log it today.',
        InsightTone.warn,
      ));
      nudges++;
    }
  }

  // 2) Best / weakest weekday over the last 90 days (schedule-aware ratio).
  final completedByDay = <DateTime, int>{};
  for (final e in entries) {
    if (e.completed) {
      final k = dayKey(e.date);
      completedByDay[k] = (completedByDay[k] ?? 0) + 1;
    }
  }
  final ratioSum = List<double>.filled(7, 0);
  final dayCount = List<int>.filled(7, 0);
  for (var i = 1; i <= 90; i++) {
    final d = addDays(today, -i);
    final expected = expectedCountOn(habits, d, today);
    if (expected == 0) continue;
    final done = completedByDay[d] ?? 0;
    final wd = d.weekday - 1;
    ratioSum[wd] += (done / expected).clamp(0.0, 1.0);
    dayCount[wd] += 1;
  }
  final scored = [
    for (var i = 0; i < 7; i++)
      if (dayCount[i] >= 3) (i, ratioSum[i] / dayCount[i])
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  if (scored.length >= 2) {
    final best = scored.first, worst = scored.last;
    if (best.$2 - worst.$2 >= 0.15) {
      out.add(Insight(
        Icons.calendar_today_outlined,
        '${_weekdayNames[best.$1]} are your strongest day '
        '(${(best.$2 * 100).round()}% done); '
        '${_weekdayNames[worst.$1].toLowerCase()} slip the most '
        '(${(worst.$2 * 100).round()}%).',
        InsightTone.neutral,
      ));
    }
  }

  // 3) Correlation: the strongest "when I do A, I also do B" pair.
  final considered = active.take(12).toList();
  final totalDays = {for (final s in byHabit.values) ...s}.length;
  (String, String, double)? bestPair;
  for (final a in considered) {
    final daysA = byHabit[a.id] ?? const <DateTime>{};
    if (daysA.length < 5) continue;
    for (final b in considered) {
      if (a.id == b.id) continue;
      final daysB = byHabit[b.id] ?? const <DateTime>{};
      if (daysB.length < 5) continue;
      final both = daysA.where(daysB.contains).length;
      final pBGivenA = both / daysA.length;
      final pB = totalDays == 0 ? 0 : daysB.length / totalDays;
      final lift = pBGivenA - pB;
      if (pBGivenA >= 0.6 && lift >= 0.25) {
        final current = bestPair;
        if (current == null || lift > current.$3) {
          bestPair = (a.name, b.name, lift);
        }
      }
    }
  }
  final pair = bestPair;
  if (pair != null) {
    out.add(Insight(
      Icons.insights_outlined,
      'On days you do ${pair.$1}, you almost always do ${pair.$2} too.',
      InsightTone.positive,
    ));
  }

  // 4) Mood ↔ habit: which habit tracks with feeling better. Only available
  // when the journal is unlocked (mood lives inside the encrypted entries).
  final journal =
      ref.watch(decryptedJournalProvider).asData?.value ?? const [];
  if (journal.isNotEmpty) {
    final moodByDay = <DateTime, List<int>>{};
    for (final d in journal) {
      final m = d.mood;
      if (m != null) {
        (moodByDay[dayKey(d.meta.createdAt)] ??= []).add(m.score);
      }
    }
    if (moodByDay.length >= 8) {
      final dayMood = {
        for (final e in moodByDay.entries)
          e.key: e.value.reduce((a, b) => a + b) / e.value.length
      };
      (String, double, double)? bestMood;
      for (final h in active) {
        final on = <double>[], off = <double>[];
        final done = byHabit[h.id] ?? const <DateTime>{};
        dayMood.forEach((day, mood) {
          (done.contains(day) ? on : off).add(mood);
        });
        if (on.length < 4 || off.length < 4) continue;
        final onAvg = on.reduce((a, b) => a + b) / on.length;
        final offAvg = off.reduce((a, b) => a + b) / off.length;
        if (onAvg - offAvg >= 0.5) {
          if (bestMood == null || onAvg - offAvg > bestMood.$2 - bestMood.$3) {
            bestMood = (h.name, onAvg, offAvg);
          }
        }
      }
      final mood = bestMood;
      if (mood != null) {
        out.add(Insight(
          Icons.sentiment_satisfied_alt_outlined,
          'Your mood runs higher on days you do ${mood.$1} '
          '(avg ${mood.$2.toStringAsFixed(1)} vs ${mood.$3.toStringAsFixed(1)}).',
          InsightTone.positive,
        ));
      }
    }
  }

  return out.take(6).toList();
});
