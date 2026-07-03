import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../data/challenge_model.dart';

const _uuid = Uuid();

final challengesProvider = StreamProvider<List<Challenge>>(
    (ref) => ref.watch(databaseProvider).watchActiveChallenges());

final challengeHabitsProvider = StreamProvider<List<ChallengeHabit>>(
    (ref) => ref.watch(databaseProvider).watchAllChallengeHabits());

final challengeServiceProvider =
    Provider<ChallengeService>((ref) => ChallengeService(ref.watch(databaseProvider)));

class ChallengeService {
  final AppDatabase _db;
  ChallengeService(this._db);

  Future<String> create({
    required String name,
    String? description,
    required DateTime start,
    required DateTime end,
    required ChallengeMode mode,
    int allowedMisses = 0,
    required Color color,
    IconData? icon,
    required List<({String habitId, bool mandatory})> habits,
  }) async {
    final id = _uuid.v4();
    await _db.insertChallenge(ChallengesCompanion.insert(
      id: id,
      name: name.trim(),
      description: Value(description),
      startDate: dayKey(start),
      endDate: dayKey(end),
      mode: Value(mode.index),
      allowedMisses: Value(allowedMisses),
      colorValue: color.toARGB32(),
      iconCodePoint: Value(icon?.codePoint),
      createdAt: DateTime.now(),
    ));
    for (final h in habits) {
      await _db.insertChallengeHabit(ChallengeHabitsCompanion.insert(
        id: _uuid.v4(),
        challengeId: id,
        habitId: h.habitId,
        mandatory: Value(h.mandatory),
      ));
    }
    return id;
  }

  Future<void> archive(String id) => _db.archiveChallenge(id);
  Future<void> remove(String id) => _db.deleteChallenge(id);
}

/// Day status within a challenge window.
const dayFuture = -1;
const dayMiss = 0;
const dayPass = 1;
const dayPending = 2; // today, not yet completed — not counted as a miss

class ChallengeProgress {
  final int totalDays;
  final int elapsedDays;
  final int passedDays;
  final int missedDays;
  final int currentStreak;
  final bool strict;
  final int allowedMisses;
  final int missesLeft;
  final double percent; // passedDays / totalDays
  final bool failed;
  final bool complete;
  final bool startsInFuture;
  final Map<DateTime, int> dayStatus;

  const ChallengeProgress({
    required this.totalDays,
    required this.elapsedDays,
    required this.passedDays,
    required this.missedDays,
    required this.currentStreak,
    required this.strict,
    required this.allowedMisses,
    required this.missesLeft,
    required this.percent,
    required this.failed,
    required this.complete,
    required this.startsInFuture,
    required this.dayStatus,
  });

  /// 25 / 50 / 75 / 100% checkpoints.
  List<bool> get milestones => [percent >= .25, percent >= .5, percent >= .75, percent >= 1.0];
}

/// Computes live progress for a challenge from habit entries in the local cache.
final challengeProgressProvider = Provider.family<ChallengeProgress, Challenge>((ref, ch) {
  final links = ref.watch(challengeHabitsProvider).asData?.value ?? const <ChallengeHabit>[];
  final entries = ref.watch(allEntriesProvider).asData?.value ?? const <HabitEntry>[];

  final myLinks = links.where((l) => l.challengeId == ch.id).toList();
  final mandatoryIds = myLinks.where((l) => l.mandatory).map((l) => l.habitId).toSet();
  final allIds = myLinks.map((l) => l.habitId).toSet();

  final completedByDay = <DateTime, Set<String>>{};
  for (final e in entries) {
    if (e.completed) (completedByDay[dayKey(e.date)] ??= {}).add(e.habitId);
  }

  bool dayPassed(DateTime d) {
    final done = completedByDay[d] ?? const <String>{};
    if (mandatoryIds.isNotEmpty) return mandatoryIds.every(done.contains);
    if (allIds.isNotEmpty) return allIds.any(done.contains);
    return false;
  }

  final start = dayKey(ch.startDate);
  final end = dayKey(ch.endDate);
  final total = end.difference(start).inDays + 1;
  final today = dayKey(DateTime.now());

  final dayStatus = <DateTime, int>{};
  int passed = 0, missed = 0, elapsed = 0;
  for (int i = 0; i < total; i++) {
    final d = start.add(Duration(days: i));
    if (d.isAfter(today)) {
      dayStatus[d] = dayFuture;
      continue;
    }
    elapsed++;
    if (dayPassed(d)) {
      passed++;
      dayStatus[d] = dayPass;
    } else if (isSameDay(d, today)) {
      dayStatus[d] = dayPending;
    } else {
      missed++;
      dayStatus[d] = dayMiss;
    }
  }

  int streak = 0;
  var cur = dayStatus[today] == dayPass ? today : today.subtract(const Duration(days: 1));
  while (!cur.isBefore(start) && dayStatus[cur] == dayPass) {
    streak++;
    cur = cur.subtract(const Duration(days: 1));
  }

  final strict = ChallengeModeX.fromIndex(ch.mode) == ChallengeMode.strict;
  final failed = strict ? missed > 0 : missed > ch.allowedMisses;
  final percent = total == 0 ? 0.0 : passed / total;
  final complete = !failed && (passed >= total || today.isAfter(end));

  return ChallengeProgress(
    totalDays: total,
    elapsedDays: elapsed.clamp(0, total),
    passedDays: passed,
    missedDays: missed,
    currentStreak: streak,
    strict: strict,
    allowedMisses: ch.allowedMisses,
    missesLeft: strict ? 0 : (ch.allowedMisses - missed).clamp(0, ch.allowedMisses),
    percent: percent,
    failed: failed,
    complete: complete,
    startsInFuture: start.isAfter(today),
    dayStatus: dayStatus,
  );
});
