import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_habits/core/db/database.dart';
import 'package:quantum_habits/features/sync/application/snapshot_codec.dart';
import 'package:quantum_habits/features/sync/application/sync_crypto.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Snapshot sample() => Snapshot(
        habits: [
          Habit(
              id: 'h1', name: 'Read', type: 1, colorValue: 123, iconCodePoint: 456,
              category: 'Mind', targetValue: 5.0, unit: 'pages', createdAt: now,
              archived: false, sortOrder: 0),
        ],
        entries: [
          HabitEntry(
              id: 'e1', habitId: 'h1', date: now, value: 3.0, completed: false,
              note: null, createdAt: now),
        ],
        challenges: [
          Challenge(
              id: 'c1', name: '75 Hard', description: null, startDate: now, endDate: now,
              mode: 0, allowedMisses: 0, colorValue: 1, iconCodePoint: null,
              createdAt: now, archived: false),
        ],
        challengeHabits: [
          ChallengeHabit(id: 'ch1', challengeId: 'c1', habitId: 'h1', mandatory: true),
        ],
        journals: [
          JournalEntry(
              id: 'j1', kind: 0, title: null, cipher: Uint8List.fromList([1, 2, 3]),
              nonce: Uint8List.fromList([4, 5]), mac: Uint8List.fromList([6, 7, 8, 9]),
              createdAt: now, updatedAt: now, archived: false),
        ],
        keyValues: [
          KeyValue(key: 'journal_salt', value: 'abc'),
          KeyValue(key: 'supabase_url', value: 'SECRET'),
        ],
      );

  test('snapshot codec round-trips all tables and strips device-local keys', () {
    final back = SnapshotCodec.decode(SnapshotCodec.encode(sample()));
    expect(back.habits.single.name, 'Read');
    expect(back.habits.single.targetValue, 5.0);
    expect(back.entries.single.value, 3.0);
    expect(back.challenges.single.name, '75 Hard');
    expect(back.challengeHabits.single.mandatory, true);
    expect(back.journals.single.cipher, Uint8List.fromList([1, 2, 3]));
    final keys = back.keyValues.map((e) => e.key);
    expect(keys, contains('journal_salt'));
    expect(keys, isNot(contains('supabase_url'))); // device-local, not synced
  });

  test('sync crypto encrypts, decrypts, and rejects a wrong passphrase', () async {
    final salt = SyncCrypto.randomSalt();
    final c = await SyncCrypto.derive('correct horse battery', salt);
    final blob = await c.encrypt('small actions compounded daily');
    expect(await c.decrypt(blob), 'small actions compounded daily');

    final wrong = await SyncCrypto.derive('not the passphrase', salt);
    await expectLater(wrong.decrypt(blob), throwsA(anything));
  });
}
