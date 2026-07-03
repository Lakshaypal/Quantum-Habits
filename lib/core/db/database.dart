import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A tracked habit. `type` stores the [HabitType] index.
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
  // historical heatmap contributions are preserved.
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic key/value store for non-secret metadata (journal salt, verifier).
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
    tables: [Habits, HabitEntries, Challenges, ChallengeHabits, JournalEntries, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'quantum_habits'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(challenges);
            await m.createTable(challengeHabits);
          }
          if (from < 3) {
            await m.createTable(journalEntries);
            await m.createTable(keyValues);
          }
          if (from < 4) {
            await m.addColumn(habits, habits.deletedAt);
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

  Future<void> insertHabit(HabitsCompanion h) => into(habits).insert(h);

  Future<void> updateHabitRow(Habit h) => update(habits).replace(h);

  Future<void> setArchived(String id, bool archived) =>
      (update(habits)..where((t) => t.id.equals(id)))
          .write(HabitsCompanion(archived: Value(archived)));

  /// Soft delete: removes the habit from the active roster but keeps the row
  /// and all its entries, so past heatmap days and history stay intact.
  Future<void> deleteHabit(String id, DateTime when) =>
      (update(habits)..where((t) => t.id.equals(id)))
          .write(HabitsCompanion(deletedAt: Value(when)));

  // ---- Entries ----
  Stream<List<HabitEntry>> watchAllEntries() => select(habitEntries).watch();

  Stream<List<HabitEntry>> watchEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitEntries)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .watch();
  }

  Future<HabitEntry?> entryFor(String habitId, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitEntries)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .getSingleOrNull();
  }

  Future<void> upsertEntry(HabitEntriesCompanion e) =>
      into(habitEntries).insertOnConflictUpdate(e);

  Future<void> deleteEntry(String id) =>
      (delete(habitEntries)..where((t) => t.id.equals(id))).go();

  // ---- Challenges ----
  Stream<List<Challenge>> watchActiveChallenges() => (select(challenges)
        ..where((t) => t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<ChallengeHabit>> watchAllChallengeHabits() =>
      select(challengeHabits).watch();

  Future<void> insertChallenge(ChallengesCompanion c) => into(challenges).insert(c);

  Future<void> insertChallengeHabit(ChallengeHabitsCompanion ch) =>
      into(challengeHabits).insert(ch);

  Future<void> archiveChallenge(String id) =>
      (update(challenges)..where((t) => t.id.equals(id)))
          .write(const ChallengesCompanion(archived: Value(true)));

  Future<void> deleteChallenge(String id) =>
      (delete(challenges)..where((t) => t.id.equals(id))).go();

  // ---- Journal ----
  Stream<List<JournalEntry>> watchJournalEntries({bool archived = false}) =>
      (select(journalEntries)
            ..where((t) => t.archived.equals(archived))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .watch();

  Future<void> upsertJournalEntry(JournalEntriesCompanion e) =>
      into(journalEntries).insertOnConflictUpdate(e);

  Future<void> setJournalArchived(String id, bool archived) =>
      (update(journalEntries)..where((t) => t.id.equals(id)))
          .write(JournalEntriesCompanion(archived: Value(archived)));

  /// Cryptographic destruction: the ciphertext row is permanently removed.
  Future<void> burnJournalEntry(String id) =>
      (delete(journalEntries)..where((t) => t.id.equals(id))).go();

  // ---- Key/value ----
  Future<String?> getKV(String key) async {
    final row =
        await (select(keyValues)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setKV(String key, String value) => into(keyValues)
      .insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));

  // ---- Sync snapshot (full export / replace) ----
  Future<List<Habit>> allHabits() => select(habits).get();
  Future<List<HabitEntry>> allHabitEntries() => select(habitEntries).get();
  Future<List<Challenge>> allChallenges() => select(challenges).get();
  Future<List<ChallengeHabit>> allChallengeHabits() => select(challengeHabits).get();
  Future<List<JournalEntry>> allJournalEntries() => select(journalEntries).get();
  Future<List<KeyValue>> allKeyValues() => select(keyValues).get();

  /// Atomically replaces all user data with a pulled snapshot. KeyValue rows
  /// are upserted (not wiped) so this device's sync config survives.
  Future<void> importSnapshot({
    required List<Habit> habitRows,
    required List<HabitEntry> entryRows,
    required List<Challenge> challengeRows,
    required List<ChallengeHabit> challengeHabitRows,
    required List<JournalEntry> journalRows,
    required List<KeyValue> keyValueRows,
  }) {
    return transaction(() async {
      await delete(challengeHabits).go();
      await delete(habitEntries).go();
      await delete(journalEntries).go();
      await delete(challenges).go();
      await delete(habits).go();
      await batch((b) {
        b.insertAll(habits, habitRows);
        b.insertAll(challenges, challengeRows);
        b.insertAll(journalEntries, journalRows);
        b.insertAll(habitEntries, entryRows);
        b.insertAll(challengeHabits, challengeHabitRows);
      });
      for (final kv in keyValueRows) {
        await into(keyValues).insertOnConflictUpdate(kv);
      }
    });
  }
}
