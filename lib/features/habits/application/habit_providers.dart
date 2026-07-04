import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../data/habit_type.dart';

const _uuid = Uuid();

/// Single app-wide database instance (offline-first source of truth).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final activeHabitsProvider = StreamProvider<List<Habit>>(
    (ref) => ref.watch(databaseProvider).watchActiveHabits());

/// Every habit including archived/deleted — for resolving names/icons of
/// historical entries (deleted habits still appear in past heatmap days).
final allHabitsAnyProvider = StreamProvider<List<Habit>>(
    (ref) => ref.watch(databaseProvider).watchAllHabitsAny());

final allEntriesProvider = StreamProvider<List<HabitEntry>>(
    (ref) => ref.watch(databaseProvider).watchAllEntries());

/// Rebinds at midnight (and on app resume) via [currentDayProvider], so an
/// app left open overnight rolls to the new day instead of freezing on the
/// day it launched.
final todayEntriesProvider = StreamProvider<List<HabitEntry>>((ref) => ref
    .watch(databaseProvider)
    .watchEntriesForDay(ref.watch(currentDayProvider)));

/// Archived habits, for the roster's archived section (restore lives there).
final archivedHabitsProvider = StreamProvider<List<Habit>>(
    (ref) => ref.watch(databaseProvider).watchArchivedHabits());

final habitServiceProvider =
    Provider<HabitService>((ref) => HabitService(ref.watch(databaseProvider)));

/// All write operations on habits/entries funnel through here.
class HabitService {
  final AppDatabase _db;
  HabitService(this._db);

  /// [id] may be supplied for template habits: a deterministic id means the
  /// same template seeded on two devices merges into ONE habit instead of
  /// duplicating.
  Future<void> addHabit({
    String? id,
    required String name,
    required HabitType type,
    required Color color,
    required IconData icon,
    String? category,
    double? target,
    String? unit,
  }) {
    return _db.insertHabit(HabitsCompanion.insert(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      type: Value(type.index),
      colorValue: color.toARGB32(),
      iconCodePoint: icon.codePoint,
      category: Value(category),
      targetValue: Value(target),
      unit: Value(unit),
      createdAt: DateTime.now(),
    ));
  }

  /// Edits a habit in place — identity, entries and history stay intact.
  Future<void> updateHabit(
    Habit existing, {
    required String name,
    required HabitType type,
    required Color color,
    required IconData icon,
    String? category,
    double? target,
    String? unit,
  }) {
    return _db.updateHabitRow(existing.copyWith(
      name: name.trim(),
      type: type.index,
      colorValue: color.toARGB32(),
      iconCodePoint: icon.codePoint,
      category: Value(category),
      targetValue: Value(target),
      unit: Value(unit),
    ));
  }

  Future<void> archive(String id) => _db.setArchived(id, true);

  Future<void> unarchive(String id) => _db.setArchived(id, false);

  /// Undo for [delete].
  Future<void> restore(String id) => _db.restoreHabit(id);

  /// Soft-deletes a habit: it leaves the active roster but its past entries and
  /// heatmap contributions remain intact.
  Future<void> delete(String id) => _db.deleteHabit(id, DateTime.now());

  /// Binary habits: tap toggles done/undone for [day].
  Future<void> toggleBinary(Habit habit, DateTime day) async {
    final existing = await _db.entryFor(habit.id, day);
    if (existing != null && existing.completed) {
      await _db.deleteEntry(existing.id);
      return;
    }
    await _writeEntry(habit, day, 1, true, existing?.id);
  }

  /// Count/time habits: bump the running value and resolve against the target.
  Future<void> increment(Habit habit, DateTime day, {double by = 1}) async {
    final existing = await _db.entryFor(habit.id, day);
    final next = (existing?.value ?? 0) + by;
    final target = habit.targetValue ?? 1;
    await _writeEntry(habit, day, next, next >= target, existing?.id);
  }

  /// Count/time habits: reduce the running value; clearing to 0 removes the
  /// day's entry entirely.
  Future<void> decrement(Habit habit, DateTime day, {double by = 1}) async {
    final existing = await _db.entryFor(habit.id, day);
    if (existing == null) return;
    final next = existing.value - by;
    if (next <= 0) {
      await _db.deleteEntry(existing.id);
      return;
    }
    final target = habit.targetValue ?? 1;
    await _writeEntry(habit, day, next, next >= target, existing.id);
  }

  Future<void> reset(Habit habit, DateTime day) async {
    final existing = await _db.entryFor(habit.id, day);
    if (existing != null) await _db.deleteEntry(existing.id);
  }

  /// Restores [day] to a captured prior state — powers one-tap UNDO. A null
  /// [prior] means "there was no entry," so we clear the day.
  Future<void> restorePrevious(Habit habit, DateTime day, HabitEntry? prior) async {
    if (prior == null) {
      await reset(habit, day);
      return;
    }
    await _db.upsertEntry(HabitEntriesCompanion(
      id: Value(prior.id),
      habitId: Value(prior.habitId),
      date: Value(prior.date),
      value: Value(prior.value),
      completed: Value(prior.completed),
      note: Value(prior.note),
      createdAt: Value(prior.createdAt),
    ));
  }

  Future<void> _writeEntry(
      Habit habit, DateTime day, double value, bool completed, String? existingId) {
    return _db.upsertEntry(HabitEntriesCompanion(
      id: Value(existingId ?? _uuid.v4()),
      habitId: Value(habit.id),
      date: Value(dayKey(day)),
      value: Value(value),
      completed: Value(completed),
      createdAt: Value(DateTime.now()),
    ));
  }
}
