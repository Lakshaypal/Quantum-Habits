import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;

const _uuid = Uuid();

/// 0 low · 1 normal · 2 high · 3 urgent.
const kPriorityLabels = ['Low', 'Normal', 'High', 'Urgent'];

final tasksProvider = StreamProvider<List<Task>>(
    (ref) => ref.watch(databaseProvider).watchTasks());

/// The to-do list, pre-bucketed the way every serious task app slices it.
class TaskBuckets {
  final List<Task> overdue;
  final List<Task> today;
  final List<Task> upcoming;
  final List<Task> someday; // no due date
  final List<Task> done;
  const TaskBuckets(
      this.overdue, this.today, this.upcoming, this.someday, this.done);

  int get openCount =>
      overdue.length + today.length + upcoming.length + someday.length;
}

final taskBucketsProvider = Provider<TaskBuckets>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value ?? const <Task>[];
  final today = ref.watch(currentDayProvider);
  final overdue = <Task>[], due = <Task>[], upcoming = <Task>[];
  final someday = <Task>[], done = <Task>[];
  for (final t in tasks) {
    if (t.done) {
      done.add(t);
    } else if (t.dueDate == null) {
      someday.add(t);
    } else {
      final d = dayKey(t.dueDate!);
      if (d.isBefore(today)) {
        overdue.add(t);
      } else if (d == today) {
        due.add(t);
      } else {
        upcoming.add(t);
      }
    }
  }
  int byPrioThenDue(Task a, Task b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null) return ad.compareTo(bd);
    return a.createdAt.compareTo(b.createdAt);
  }

  overdue.sort(byPrioThenDue);
  due.sort(byPrioThenDue);
  upcoming.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  someday.sort(byPrioThenDue);
  done.sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));
  return TaskBuckets(overdue, due, upcoming, someday,
      done.take(30).toList() /* recent completions only */);
});

final taskServiceProvider =
    Provider<TaskService>((ref) => TaskService(ref.watch(databaseProvider)));

class TaskService {
  final AppDatabase _db;
  TaskService(this._db);

  Future<void> add({
    required String title,
    String? notes,
    DateTime? dueDate,
    int? dueMinutes,
    int priority = 1,
  }) {
    return _db.upsertTask(TasksCompanion.insert(
      id: _uuid.v4(),
      title: title.trim(),
      notes: Value(notes),
      dueDate: Value(dueDate == null ? null : dayKey(dueDate)),
      dueMinutes: Value(dueMinutes),
      priority: Value(priority),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> update(
    Task existing, {
    required String title,
    String? notes,
    DateTime? dueDate,
    int? dueMinutes,
    int priority = 1,
  }) {
    return _db.upsertTask(TasksCompanion(
      id: Value(existing.id),
      title: Value(title.trim()),
      notes: Value(notes),
      dueDate: Value(dueDate == null ? null : dayKey(dueDate)),
      dueMinutes: Value(dueMinutes),
      priority: Value(priority),
      done: Value(existing.done),
      doneAt: Value(existing.doneAt),
      createdAt: Value(existing.createdAt),
      sortOrder: Value(existing.sortOrder),
    ));
  }

  Future<void> setDone(String id, bool done) => _db.setTaskDone(id, done);

  Future<void> remove(String id) => _db.deleteTask(id);

  /// Undo for [remove].
  Future<void> restore(Task t) => _db.upsertTask(t.toCompanion(false));
}
