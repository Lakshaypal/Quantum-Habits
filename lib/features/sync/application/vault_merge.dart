import '../../../core/db/database.dart';
import 'vault_codec.dart';

/// Outcome of merging the local database with a remote vault.
class MergeResult {
  /// The converged record set — what the vault file should now contain.
  final VaultData merged;

  /// Rows whose winning version differs from what this device holds — the
  /// only writes needed locally.
  final VaultData toWriteLocal;

  /// True when the winning set differs from the remote vault, i.e. an upload
  /// is required.
  final bool remoteChanged;

  const MergeResult(this.merged, this.toWriteLocal, this.remoteChanged);

  bool get localChanged =>
      toWriteLocal.habits.isNotEmpty ||
      toWriteLocal.entries.isNotEmpty ||
      toWriteLocal.challenges.isNotEmpty ||
      toWriteLocal.challengeHabits.isNotEmpty ||
      toWriteLocal.journals.isNotEmpty ||
      toWriteLocal.keyValues.isNotEmpty;
}

/// Per-record last-writer-wins merge.
///
/// Guarantees:
///  - Convergent: merge(a, b) and merge(b, a) produce the same record set, so
///    every device settles on identical data regardless of sync order.
///  - Non-destructive: a record only ever loses to a strictly newer version
///    of itself (or a deterministic tie-break) — never to a whole-vault
///    overwrite. Offline edits on two devices interleave instead of one side
///    being wiped.
///  - Deletes propagate: tombstones are records too, so a delete beats an
///    older live row and can never be resurrected by a stale device.
abstract final class VaultMerge {
  static MergeResult merge(VaultData local, VaultData remote) {
    final habits = _mergeTable<Habit>(
        local.habits, remote.habits, (h) => h.id, (h) => h.updatedAtMs,
        (h) => h.deletedAt != null, VaultCodec.habitJson);
    final challenges = _mergeTable<Challenge>(
        local.challenges, remote.challenges, (c) => c.id, (c) => c.updatedAtMs,
        (c) => c.deleted, VaultCodec.challengeJson);
    final journals = _mergeTable<JournalEntry>(
        local.journals, remote.journals, (j) => j.id, (j) => j.updatedAtMs,
        (j) => j.deleted, VaultCodec.journalJson);
    final kvs = _mergeTable<KeyValue>(
        local.keyValues, remote.keyValues, (k) => k.key, (k) => k.updatedAtMs,
        (_) => false, VaultCodec.kvJson);

    // Entries and challenge links have a logical identity beyond their row id
    // (two offline devices can create different rows for the same habit+day),
    // so after LWW they get canonicalized: exactly one live row per logical
    // key, losers tombstoned. Canonicalization is a pure function of the
    // merged set, so every device computes the same outcome.
    final entries = _canonicalize<HabitEntry>(
      _mergeTable<HabitEntry>(local.entries, remote.entries, (e) => e.id,
          (e) => e.updatedAtMs, (e) => e.deleted, VaultCodec.entryJson),
      logicalKey: (e) => '${e.habitId}|${VaultCodec.dayStr(e.date)}',
      isDeleted: (e) => e.deleted,
      updatedAt: (e) => e.updatedAtMs,
      id: (e) => e.id,
      tombstone: (e) => e.copyWith(deleted: true),
    );
    final links = _canonicalize<ChallengeHabit>(
      _mergeTable<ChallengeHabit>(local.challengeHabits, remote.challengeHabits,
          (l) => l.id, (l) => l.updatedAtMs, (l) => l.deleted,
          VaultCodec.chLinkJson),
      logicalKey: (l) => '${l.challengeId}|${l.habitId}',
      isDeleted: (l) => l.deleted,
      updatedAt: (l) => l.updatedAtMs,
      id: (l) => l.id,
      tombstone: (l) => l.copyWith(deleted: true),
    );

    final merged = VaultData(
      habits: habits,
      entries: entries,
      challenges: challenges,
      challengeHabits: links,
      journals: journals,
      keyValues: kvs,
    );

    final toLocal = VaultData(
      habits: _diff(merged.habits, local.habits, (h) => h.id, VaultCodec.habitJson),
      entries: _diff(merged.entries, local.entries, (e) => e.id, VaultCodec.entryJson),
      challenges: _diff(merged.challenges, local.challenges, (c) => c.id,
          VaultCodec.challengeJson),
      challengeHabits: _diff(merged.challengeHabits, local.challengeHabits,
          (l) => l.id, VaultCodec.chLinkJson),
      journals: _diff(merged.journals, local.journals, (j) => j.id,
          VaultCodec.journalJson),
      keyValues: _diff(merged.keyValues, local.keyValues, (k) => k.key,
          VaultCodec.kvJson),
    );

    final remoteChanged =
        _diff(merged.habits, remote.habits, (h) => h.id, VaultCodec.habitJson).isNotEmpty ||
            _diff(merged.entries, remote.entries, (e) => e.id, VaultCodec.entryJson).isNotEmpty ||
            _diff(merged.challenges, remote.challenges, (c) => c.id, VaultCodec.challengeJson).isNotEmpty ||
            _diff(merged.challengeHabits, remote.challengeHabits, (l) => l.id, VaultCodec.chLinkJson).isNotEmpty ||
            _diff(merged.journals, remote.journals, (j) => j.id, VaultCodec.journalJson).isNotEmpty ||
            _diff(merged.keyValues, remote.keyValues, (k) => k.key, VaultCodec.kvJson).isNotEmpty;

    return MergeResult(merged, toLocal, remoteChanged);
  }

  /// LWW by `updatedAt`; ties broken deterministically (tombstone wins, then
  /// greater canonical JSON) so both merge directions agree.
  static List<T> _mergeTable<T>(
    List<T> local,
    List<T> remote,
    String Function(T) id,
    int Function(T) updatedAt,
    bool Function(T) isDeleted,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final l = {for (final r in local) id(r): r};
    final r = {for (final row in remote) id(row): row};
    final out = <T>[];
    for (final key in {...l.keys, ...r.keys}) {
      final a = l[key], b = r[key];
      if (a == null) {
        out.add(b as T);
      } else if (b == null) {
        out.add(a);
      } else {
        out.add(_winner(a, b, updatedAt, isDeleted, toJson));
      }
    }
    return out;
  }

  static T _winner<T>(T a, T b, int Function(T) updatedAt,
      bool Function(T) isDeleted, Map<String, dynamic> Function(T) toJson) {
    final ua = updatedAt(a), ub = updatedAt(b);
    if (ua != ub) return ua > ub ? a : b;
    final da = isDeleted(a), db = isDeleted(b);
    if (da != db) return da ? a : b; // deletion wins ties
    final ja = VaultCodec.canonical(toJson(a)), jb = VaultCodec.canonical(toJson(b));
    return ja.compareTo(jb) >= 0 ? a : b;
  }

  /// Collapses duplicate live rows sharing a logical key: highest updatedAt
  /// (then greatest id) survives, the rest are tombstoned.
  static List<T> _canonicalize<T>(
    List<T> rows, {
    required String Function(T) logicalKey,
    required bool Function(T) isDeleted,
    required int Function(T) updatedAt,
    required String Function(T) id,
    required T Function(T) tombstone,
  }) {
    final groups = <String, List<T>>{};
    for (final row in rows.where((r) => !isDeleted(r))) {
      groups.putIfAbsent(logicalKey(row), () => []).add(row);
    }
    final losers = <String>{};
    for (final group in groups.values.where((g) => g.length > 1)) {
      group.sort((a, b) {
        final byTime = updatedAt(b).compareTo(updatedAt(a));
        return byTime != 0 ? byTime : id(b).compareTo(id(a));
      });
      losers.addAll(group.skip(1).map(id));
    }
    if (losers.isEmpty) return rows;
    return [
      for (final row in rows) losers.contains(id(row)) ? tombstone(row) : row
    ];
  }

  /// Rows in [winners] that differ from their counterpart in [base].
  static List<T> _diff<T>(List<T> winners, List<T> base, String Function(T) id,
      Map<String, dynamic> Function(T) toJson) {
    final baseJson = {
      for (final row in base) id(row): VaultCodec.canonical(toJson(row))
    };
    return [
      for (final row in winners)
        if (baseJson[id(row)] != VaultCodec.canonical(toJson(row))) row
    ];
  }
}
