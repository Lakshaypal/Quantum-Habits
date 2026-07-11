import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A tracked habit. `type` stores the [HabitType] index.
///
/// Sync: every synced table carries `updatedAtMs` (epoch-ms of the last local
/// mutation) so devices can merge per record with last-writer-wins, and a
/// tombstone marker so deletes propagate instead of resurrecting.
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  TextColumn get category => text().nullable()();
  RealColumn get targetValue => real().nullable()();
  TextColumn get unit => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  // Soft delete: set, the habit leaves the active roster but its entries and
  // historical heatmap contributions are preserved. Doubles as the tombstone.
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();
  // Cadence (see HabitSchedule): 0 daily · 1 specific weekdays · 2 N-per-week.
  IntColumn get scheduleKind => integer().withDefault(const Constant(0))();
  // weekdays → weekday bitmask; N-per-week → target count.
  IntColumn get scheduleMask => integer().withDefault(const Constant(0))();
  // Minutes since local midnight for a daily reminder; null = no reminder.
  IntColumn get reminderMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One completion record for a habit on a given day. `value` carries the count
/// or minutes; `completed` is the resolved pass/fail for the day.
class HabitEntries extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get value => real().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A user-defined challenge (e.g. 75 Hard, 100 Days of Code). `mode` is the
/// [ChallengeMode] index; strict resets on a miss, flexible allows misses.
class Challenges extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  IntColumn get allowedMisses => integer().withDefault(const Constant(0))();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Links a habit to a challenge; `mandatory` habits gate whether a day passes.
class ChallengeHabits extends Table {
  TextColumn get id => text()();
  TextColumn get challengeId =>
      text().references(Challenges, #id, onDelete: KeyAction.cascade)();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  BoolColumn get mandatory => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// An encrypted journal entry. The body never touches disk in plaintext —
/// `cipher`/`nonce`/`mac` are the AES-256-GCM SecretBox components.
class JournalEntries extends Table {
  TextColumn get id => text()();
  IntColumn get kind => integer().withDefault(const Constant(0))();
  TextColumn get title => text().nullable()();
  BlobColumn get cipher => blob()();
  BlobColumn get nonce => blob()();
  BlobColumn get mac => blob()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A one-off to-do item. Unlike habits (recurring, streak-scored), tasks are
/// done once: optional due day + time, 0–3 priority, tombstoned on delete.
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()(); // local midnight
  IntColumn get dueMinutes => integer().nullable()(); // minutes since midnight
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic key/value store for non-secret metadata (journal salt, verifier,
/// theme preferences). Synced per key with last-writer-wins; device-local keys
/// are excluded by the vault codec.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Habits,
  HabitEntries,
  Challenges,
  ChallengeHabits,
  JournalEntries,
  Tasks,
  KeyValues
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'quantum_habits'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// addColumn that tolerates the column already existing. A migration can
  /// be re-attempted after a partial run (force-kill mid-upgrade, or two
  /// instances racing) — sqlite's user_version only advances on success, so
  /// every step must be safe to replay.
  Future<void> _addColumnSafe(
      Migrator m, TableInfo table, GeneratedColumn column) async {
    try {
      await m.addColumn(table, column);
    } on Exception catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }

  Future<void> _createTableSafe(Migrator m, TableInfo table) async {
    try {
      await m.createTable(table);
    } on Exception catch (e) {
      if (!e.toString().contains('already exists')) rethrow;
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _createTableSafe(m, challenges);
            await _createTableSafe(m, challengeHabits);
          }
          if (from < 3) {
            await _createTableSafe(m, journalEntries);
            await _createTableSafe(m, keyValues);
          }
          if (from < 4) {
            await _addColumnSafe(m, habits, habits.deletedAt);
          }
          if (from < 5) {
            await _addColumnSafe(m, habits, habits.updatedAtMs);
            await _addColumnSafe(m, habitEntries, habitEntries.deleted);
            await _addColumnSafe(m, habitEntries, habitEntries.updatedAtMs);
            await _addColumnSafe(m, challenges, challenges.deleted);
            await _addColumnSafe(m, challenges, challenges.updatedAtMs);
            await _addColumnSafe(m, challengeHabits, challengeHabits.deleted);
            await _addColumnSafe(m, challengeHabits, challengeHabits.updatedAtMs);
            await _addColumnSafe(m, journalEntries, journalEntries.deleted);
            await _addColumnSafe(m, journalEntries, journalEntries.updatedAtMs);
            await _addColumnSafe(m, keyValues, keyValues.updatedAtMs);
            // Backfill sensible merge timestamps for pre-sync-v2 rows
            // (drift stores dateTime as unix seconds).
            await customStatement(
                'UPDATE habits SET updated_at_ms = created_at * 1000');
            await customStatement(
                'UPDATE habit_entries SET updated_at_ms = created_at * 1000');
            await customStatement(
                'UPDATE challenges SET updated_at_ms = created_at * 1000');
            await customStatement(
                'UPDATE journal_entries SET updated_at_ms = updated_at * 1000');
          }
          if (from < 6) {
            await _addColumnSafe(m, habits, habits.scheduleKind);
            await _addColumnSafe(m, habits, habits.scheduleMask);
            await _addColumnSafe(m, habits, habits.reminderMinutes);
          }
          if (from < 7) {
            await _createTableSafe(m, tasks);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---- Habits ----
  /// The active roster — excludes archived and soft-deleted habits.
  Stream<List<Habit>> watchActiveHabits() => (select(habits)
        ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .watch();

  /// Every habit ever created, including archived/deleted — used to resolve
  /// names & icons for historical entries in the heatmap and day views.
  Stream<List<Habit>> watchAllHabitsAny() => select(habits).watch();

  /// Archived (but not deleted) habits — the recoverable shelf.
  Stream<List<Habit>> watchArchivedHabits() => (select(habits)
        ..where((t) => t.archived.equals(true) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .watch();

  Future<void> insertHabit(HabitsCompanion h) =>
      into(habits).insert(h.copyWith(updatedAtMs: Value(_now())));

  Future<void> updateHabitRow(Habit h) =>
      update(habits).replace(h.copyWith(updatedAtMs: _now()));

  Future<void> setArchived(String id, bool archived) =>
      (update(habits)..where((t) => t.id.equals(id))).write(HabitsCompanion(
          archived: Value(archived), updatedAtMs: Value(_now())));

  /// Soft delete: removes the habit from the active roster but keeps the row
  /// and all its entries, so past heatmap days and history stay intact.
  Future<void> deleteHabit(String id, DateTime when) =>
      (update(habits)..where((t) => t.id.equals(id))).write(HabitsCompanion(
          deletedAt: Value(when), updatedAtMs: Value(_now())));

  /// Undo for [deleteHabit] — clears the tombstone.
  Future<void> restoreHabit(String id) =>
      (update(habits)..where((t) => t.id.equals(id))).write(HabitsCompanion(
          deletedAt: const Value(null), updatedAtMs: Value(_now())));

  // ---- Entries ----
  Stream<List<HabitEntry>> watchAllEntries() =>
      (select(habitEntries)..where((t) => t.deleted.equals(false))).watch();

  Stream<List<HabitEntry>> watchEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitEntries)
          ..where((t) =>
              t.deleted.equals(false) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .watch();
  }

  /// Tolerant of duplicate rows for one habit+day (possible mid-sync): the
  /// newest row wins instead of crashing a getSingle call.
  Future<HabitEntry?> entryFor(String habitId, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitEntries)
          ..where((t) =>
              t.deleted.equals(false) &
              t.habitId.equals(habitId) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.updatedAtMs, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Upserting an id that was tombstoned revives it (used by undo).
  Future<void> upsertEntry(HabitEntriesCompanion e) =>
      into(habitEntries).insertOnConflictUpdate(e.copyWith(
          deleted: const Value(false), updatedAtMs: Value(_now())));

  /// Tombstone, not a hard delete — the deletion must outlive the row so it
  /// propagates to other devices instead of being resurrected by them.
  Future<void> deleteEntry(String id) =>
      (update(habitEntries)..where((t) => t.id.equals(id))).write(
          HabitEntriesCompanion(
              deleted: const Value(true), updatedAtMs: Value(_now())));

  // ---- Challenges ----
  Stream<List<Challenge>> watchActiveChallenges() => (select(challenges)
        ..where((t) => t.archived.equals(false) & t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<ChallengeHabit>> watchAllChallengeHabits() =>
      (select(challengeHabits)..where((t) => t.deleted.equals(false))).watch();

  Future<void> insertChallenge(ChallengesCompanion c) =>
      into(challenges).insert(c.copyWith(updatedAtMs: Value(_now())));

  Future<void> updateChallengeRow(Challenge c) =>
      update(challenges).replace(c.copyWith(updatedAtMs: _now()));

  /// Upsert: also used to flip `mandatory` or revive a tombstoned link.
  Future<void> insertChallengeHabit(ChallengeHabitsCompanion ch) =>
      into(challengeHabits).insertOnConflictUpdate(ch.copyWith(
          deleted: const Value(false), updatedAtMs: Value(_now())));

  /// Detaches a habit from a challenge (tombstoned so it syncs).
  Future<void> removeChallengeHabit(String id) =>
      (update(challengeHabits)..where((t) => t.id.equals(id))).write(
          ChallengeHabitsCompanion(
              deleted: const Value(true), updatedAtMs: Value(_now())));

  Stream<List<Challenge>> watchArchivedChallenges() => (select(challenges)
        ..where((t) => t.archived.equals(true) & t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Future<void> archiveChallenge(String id) =>
      (update(challenges)..where((t) => t.id.equals(id))).write(
          ChallengesCompanion(
              archived: const Value(true), updatedAtMs: Value(_now())));

  Future<void> unarchiveChallenge(String id) =>
      (update(challenges)..where((t) => t.id.equals(id))).write(
          ChallengesCompanion(
              archived: const Value(false), updatedAtMs: Value(_now())));

  /// Tombstones the challenge and its habit links.
  Future<void> deleteChallenge(String id) => transaction(() async {
        final now = _now();
        await (update(challenges)..where((t) => t.id.equals(id))).write(
            ChallengesCompanion(
                deleted: const Value(true), updatedAtMs: Value(now)));
        await (update(challengeHabits)..where((t) => t.challengeId.equals(id)))
            .write(ChallengeHabitsCompanion(
                deleted: const Value(true), updatedAtMs: Value(now)));
      });

  // ---- Journal ----
  Stream<List<JournalEntry>> watchJournalEntries({bool archived = false}) =>
      (select(journalEntries)
            ..where((t) => t.archived.equals(archived) & t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .watch();

  Future<void> upsertJournalEntry(JournalEntriesCompanion e) =>
      into(journalEntries).insertOnConflictUpdate(e.copyWith(
          deleted: const Value(false), updatedAtMs: Value(_now())));

  Future<void> setJournalArchived(String id, bool archived) =>
      (update(journalEntries)..where((t) => t.id.equals(id))).write(
          JournalEntriesCompanion(
              archived: Value(archived), updatedAtMs: Value(_now())));

  /// Cryptographic destruction: ciphertext is zeroed AND the row is tombstoned,
  /// so the burn propagates to every synced device instead of the entry
  /// reappearing from a remote copy.
  Future<void> burnJournalEntry(String id) =>
      (update(journalEntries)..where((t) => t.id.equals(id))).write(
          JournalEntriesCompanion(
              cipher: Value(Uint8List(0)),
              nonce: Value(Uint8List(0)),
              mac: Value(Uint8List(0)),
              deleted: const Value(true),
              updatedAtMs: Value(_now())));

  // ---- Tasks ----
  Stream<List<Task>> watchTasks() => (select(tasks)
        ..where((t) => t.deleted.equals(false))
        ..orderBy([
          (t) => OrderingTerm(expression: t.done),
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .watch();

  /// Upsert; also revives a tombstoned id (undo).
  Future<void> upsertTask(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task.copyWith(
          deleted: const Value(false), updatedAtMs: Value(_now())));

  Future<void> setTaskDone(String id, bool done) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
        done: Value(done),
        doneAt: Value(done ? DateTime.now() : null),
        updatedAtMs: Value(_now()),
      ));

  /// Tombstone, so the deletion syncs instead of resurrecting.
  Future<void> deleteTask(String id) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
          deleted: const Value(true), updatedAtMs: Value(_now())));

  Future<List<Task>> allTasks() => select(tasks).get();

  // ---- Key/value ----
  Future<String?> getKV(String key) async {
    final row =
        await (select(keyValues)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchKV(String key) =>
      (select(keyValues)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> setKV(String key, String value) =>
      into(keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(
          key: key, value: value, updatedAtMs: Value(_now())));

  Future<void> deleteKV(String key) =>
      (delete(keyValues)..where((t) => t.key.equals(key))).go();

  // ---- Sync: full-table reads (tombstones included — the vault needs them) ----
  Future<List<Habit>> allHabits() => select(habits).get();
  Future<List<HabitEntry>> allHabitEntries() => select(habitEntries).get();
  Future<List<Challenge>> allChallenges() => select(challenges).get();
  Future<List<ChallengeHabit>> allChallengeHabits() => select(challengeHabits).get();
  Future<List<JournalEntry>> allJournalEntries() => select(journalEntries).get();
  Future<List<KeyValue>> allKeyValues() => select(keyValues).get();

  /// Applies rows that won a merge against this device's data. Rows are
  /// written verbatim — remote `updatedAtMs` values are preserved, never
  /// restamped, so merges stay convergent across devices.
  Future<void> applyMergedRows({
    List<Habit> habitRows = const [],
    List<HabitEntry> entryRows = const [],
    List<Challenge> challengeRows = const [],
    List<ChallengeHabit> challengeHabitRows = const [],
    List<JournalEntry> journalRows = const [],
    List<Task> taskRows = const [],
    List<KeyValue> keyValueRows = const [],
  }) {
    return transaction(() async {
      await batch((b) {
        // Parents before children (FK constraints are live).
        b.insertAllOnConflictUpdate(habits, habitRows);
        b.insertAllOnConflictUpdate(challenges, challengeRows);
        b.insertAllOnConflictUpdate(journalEntries, journalRows);
        b.insertAllOnConflictUpdate(habitEntries, entryRows);
        b.insertAllOnConflictUpdate(challengeHabits, challengeHabitRows);
        b.insertAllOnConflictUpdate(tasks, taskRows);
        b.insertAllOnConflictUpdate(keyValues, keyValueRows);
      });
    });
  }
}
