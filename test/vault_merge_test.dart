import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_habits/core/db/database.dart';
import 'package:quantum_habits/features/sync/application/vault_codec.dart';
import 'package:quantum_habits/features/sync/application/vault_merge.dart';

Habit habit(String id,
        {String name = 'Read',
        int up = 100,
        DateTime? deletedAt,
        bool archived = false}) =>
    Habit(
      id: id,
      name: name,
      type: 0,
      colorValue: 0xFF000000,
      iconCodePoint: 1,
      category: null,
      targetValue: null,
      unit: null,
      createdAt: DateTime(2026, 1, 1),
      archived: archived,
      sortOrder: 0,
      deletedAt: deletedAt,
      updatedAtMs: up,
    );

HabitEntry entry(String id, String habitId, DateTime day,
        {double value = 1,
        bool completed = true,
        bool deleted = false,
        int up = 100,
        String? note}) =>
    HabitEntry(
      id: id,
      habitId: habitId,
      date: day,
      value: value,
      completed: completed,
      note: note,
      createdAt: DateTime(2026, 1, 1),
      deleted: deleted,
      updatedAtMs: up,
    );

JournalEntry journal(String id,
        {bool deleted = false, int up = 100, List<int> cipher = const [1, 2]}) =>
    JournalEntry(
      id: id,
      kind: 0,
      title: 'T',
      cipher: Uint8List.fromList(cipher),
      nonce: Uint8List.fromList([3]),
      mac: Uint8List.fromList([4]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      archived: false,
      deleted: deleted,
      updatedAtMs: up,
    );

KeyValue kv(String k, String v, {int up = 100}) =>
    KeyValue(key: k, value: v, updatedAtMs: up);

void main() {
  group('VaultMerge', () {
    test('newer edit wins per record, both directions agree', () {
      final a = VaultData(habits: [habit('h1', name: 'Old', up: 100)]);
      final b = VaultData(habits: [habit('h1', name: 'New', up: 200)]);
      final ab = VaultMerge.merge(a, b);
      final ba = VaultMerge.merge(b, a);
      expect(ab.merged.habits.single.name, 'New');
      expect(ba.merged.habits.single.name, 'New');
      expect(ab.toWriteLocal.habits.single.name, 'New');
      expect(ba.toWriteLocal.habits, isEmpty);
      expect(ab.remoteChanged, isFalse);
      expect(ba.remoteChanged, isTrue);
    });

    test('offline edits on two devices interleave — nothing is lost', () {
      final day1 = DateTime(2026, 7, 1);
      final day2 = DateTime(2026, 7, 2);
      final local = VaultData(
        habits: [habit('h1')],
        entries: [entry('e1', 'h1', day1, up: 150)],
      );
      final remote = VaultData(
        habits: [habit('h1')],
        entries: [entry('e2', 'h1', day2, up: 160)],
      );
      final r = VaultMerge.merge(local, remote);
      expect(r.merged.entries.length, 2);
      expect(r.remoteChanged, isTrue, reason: 'remote lacks e1');
      expect(r.toWriteLocal.entries.map((e) => e.id), ['e2']);
    });

    test('delete beats older live row and never resurrects', () {
      final deleted = habit('h1', deletedAt: DateTime(2026, 6, 1), up: 300);
      final stale = habit('h1', up: 100);
      for (final r in [
        VaultMerge.merge(VaultData(habits: [deleted]), VaultData(habits: [stale])),
        VaultMerge.merge(VaultData(habits: [stale]), VaultData(habits: [deleted])),
      ]) {
        expect(r.merged.habits.single.deletedAt, isNotNull);
      }
    });

    test('edit newer than delete revives the record (LWW)', () {
      final deleted = habit('h1', deletedAt: DateTime(2026, 6, 1), up: 300);
      final revived = habit('h1', up: 400);
      final r = VaultMerge.merge(
          VaultData(habits: [deleted]), VaultData(habits: [revived]));
      expect(r.merged.habits.single.deletedAt, isNull);
    });

    test('tombstoned journal burn propagates (cipher stays destroyed)', () {
      final burned = journal('j1', deleted: true, cipher: const [], up: 500);
      final intact = journal('j1', up: 100);
      final r = VaultMerge.merge(
          VaultData(journals: [intact]), VaultData(journals: [burned]));
      final winner = r.merged.journals.single;
      expect(winner.deleted, isTrue);
      expect(winner.cipher, isEmpty);
    });

    test('same-timestamp conflict is deterministic and convergent', () {
      final x = habit('h1', name: 'Alpha', up: 100);
      final y = habit('h1', name: 'Beta', up: 100);
      final ab = VaultMerge.merge(VaultData(habits: [x]), VaultData(habits: [y]));
      final ba = VaultMerge.merge(VaultData(habits: [y]), VaultData(habits: [x]));
      expect(ab.merged.habits.single.name, ba.merged.habits.single.name);
    });

    test('tombstone wins a same-timestamp tie', () {
      final live = entry('e1', 'h1', DateTime(2026, 7, 1), up: 100);
      final dead = entry('e1', 'h1', DateTime(2026, 7, 1), deleted: true, up: 100);
      final r = VaultMerge.merge(
          VaultData(entries: [live]), VaultData(entries: [dead]));
      expect(r.merged.entries.single.deleted, isTrue);
    });

    test('duplicate entries for one habit+day collapse to a single live row',
        () {
      final day = DateTime(2026, 7, 1);
      final local = VaultData(entries: [entry('aaa', 'h1', day, up: 100)]);
      final remote = VaultData(entries: [entry('bbb', 'h1', day, up: 200)]);
      final ab = VaultMerge.merge(local, remote);
      final ba = VaultMerge.merge(remote, local);
      for (final r in [ab, ba]) {
        final live = r.merged.entries.where((e) => !e.deleted).toList();
        expect(live.length, 1);
        expect(live.single.id, 'bbb', reason: 'newer row survives');
        expect(r.merged.entries.length, 2, reason: 'loser kept as tombstone');
      }
    });

    test('key-values merge LWW by key', () {
      final r = VaultMerge.merge(
        VaultData(keyValues: [kv('theme', 'dark', up: 100), kv('a', '1')]),
        VaultData(keyValues: [kv('theme', 'light', up: 200), kv('b', '2')]),
      );
      final m = {for (final k in r.merged.keyValues) k.key: k.value};
      expect(m, {'theme': 'light', 'a': '1', 'b': '2'});
    });

    test('identical vaults are a no-op in both directions', () {
      final v = VaultData(
        habits: [habit('h1')],
        entries: [entry('e1', 'h1', DateTime(2026, 7, 1))],
        keyValues: [kv('k', 'v')],
      );
      final r = VaultMerge.merge(v, v);
      expect(r.localChanged, isFalse);
      expect(r.remoteChanged, isFalse);
    });

    test('merge is idempotent: re-merging the merged set changes nothing', () {
      final day = DateTime(2026, 7, 1);
      final local = VaultData(
        habits: [habit('h1', name: 'L', up: 300)],
        entries: [entry('aaa', 'h1', day, up: 100)],
      );
      final remote = VaultData(
        habits: [habit('h1', name: 'R', up: 200)],
        entries: [entry('bbb', 'h1', day, up: 200)],
      );
      final once = VaultMerge.merge(local, remote);
      final again = VaultMerge.merge(once.merged, once.merged);
      expect(again.localChanged, isFalse);
      expect(again.remoteChanged, isFalse);
    });
  });

  group('VaultCodec', () {
    test('round-trips every field including tombstones and deletedAt', () {
      final v = VaultData(
        habits: [
          habit('h1', deletedAt: DateTime(2026, 6, 15), up: 42),
          habit('h2', archived: true),
        ],
        entries: [
          entry('e1', 'h1', DateTime(2026, 7, 1),
              value: 2.5, completed: false, note: 'hi', deleted: true, up: 7)
        ],
        journals: [journal('j1', deleted: true, cipher: const [])],
        keyValues: [kv('theme', 'dark', up: 5)],
      );
      final decoded = VaultCodec.decode(VaultCodec.encode(v));
      expect(VaultCodec.canonical(VaultCodec.habitJson(decoded.habits[0])),
          VaultCodec.canonical(VaultCodec.habitJson(v.habits[0])));
      expect(VaultCodec.canonical(VaultCodec.habitJson(decoded.habits[1])),
          VaultCodec.canonical(VaultCodec.habitJson(v.habits[1])));
      expect(VaultCodec.canonical(VaultCodec.entryJson(decoded.entries.single)),
          VaultCodec.canonical(VaultCodec.entryJson(v.entries.single)));
      expect(
          VaultCodec.canonical(VaultCodec.journalJson(decoded.journals.single)),
          VaultCodec.canonical(VaultCodec.journalJson(v.journals.single)));
      expect(decoded.keyValues.single.value, 'dark');
      expect(decoded.keyValues.single.updatedAtMs, 5);
    });

    test('entry dates travel as calendar days, not instants', () {
      final e = entry('e1', 'h1', DateTime(2026, 7, 1));
      final json = VaultCodec.entryJson(e);
      expect(json['day'], '2026-07-01');
      expect(VaultCodec.entryFrom(json).date, DateTime(2026, 7, 1));
    });

    test('device-local keys never travel', () {
      final v = VaultData(keyValues: [
        kv('device_id', 'x'),
        kv('drive_file_id', 'y'),
        kv('gdrive_client_id', 'z'),
        kv('supabase_url', 'legacy'),
        kv('theme', 'dark'),
      ]);
      final decoded = VaultCodec.decode(VaultCodec.encode(v));
      expect(decoded.keyValues.map((k) => k.key), ['theme']);
    });

    test('rejects unknown vault versions loudly', () {
      expect(() => VaultCodec.decode(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FormatException>()));
    });
  });
}
