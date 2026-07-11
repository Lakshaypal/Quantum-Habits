import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/db/database.dart';

/// KeyValue keys that are device-local and must NOT travel in a vault:
/// identity/bookkeeping for THIS device, plus legacy Supabase-era keys so old
/// databases never leak their config into the cloud.
const kLocalOnlyKeys = <String>{
  'device_id',
  'last_synced_at',
  'drive_file_id',
  'drive_last_version',
  'gdrive_client_id',
  'gdrive_email',
  'sync_auto',
  'last_update_check',
  'pref_quote_notifs',
  'pref_auto_update',
  // Legacy (pre-Drive) keys — excluded defensively.
  'supabase_url',
  'supabase_anon_key',
  'sync_salt',
};

/// All syncable rows of the database, tombstones included. This is what a
/// device holds locally and what the Drive vault file contains — merging two
/// of these per record is the whole sync model.
class VaultData {
  final List<Habit> habits;
  final List<HabitEntry> entries;
  final List<Challenge> challenges;
  final List<ChallengeHabit> challengeHabits;
  final List<JournalEntry> journals;
  final List<Task> tasks;
  final List<KeyValue> keyValues;
  const VaultData({
    this.habits = const [],
    this.entries = const [],
    this.challenges = const [],
    this.challengeHabits = const [],
    this.journals = const [],
    this.tasks = const [],
    this.keyValues = const [],
  });

  static Future<VaultData> fromDb(AppDatabase db) async => VaultData(
        habits: await db.allHabits(),
        entries: await db.allHabitEntries(),
        challenges: await db.allChallenges(),
        challengeHabits: await db.allChallengeHabits(),
        journals: await db.allJournalEntries(),
        tasks: await db.allTasks(),
        keyValues: (await db.allKeyValues())
            .where((kv) => !kLocalOnlyKeys.contains(kv.key))
            .toList(),
      );
}

/// The vault on Drive was written by a NEWER app than this one — the caller
/// must not overwrite it (that would destroy data this version can't read).
class VaultTooNewException implements Exception {
  final int found;
  VaultTooNewException(this.found);
  @override
  String toString() =>
      'This device runs an older app version — update it to keep syncing.';
}

/// Vault format v2: per-record rows with `updatedAtMs` + tombstones, gzipped
/// JSON. Instants are epoch-ms; day-keyed fields (entry dates, challenge
/// start/end) travel as 'yyyy-MM-dd' strings so a completion logged on
/// Tuesday stays on Tuesday regardless of the receiving device's timezone.
///
/// Decoding is defensive: one corrupt record is skipped, not fatal — a new
/// device signing in against a vault containing garbage rows still gets
/// everything readable instead of a broken sync.
abstract final class VaultCodec {
  static const version = 2;

  static int _ms(DateTime d) => d.millisecondsSinceEpoch;
  static DateTime _dt(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
  static String _b64(Uint8List b) => base64.encode(b);
  static Uint8List _unb64(Object? v) =>
      Uint8List.fromList(base64.decode(v as String));

  /// Calendar day → 'yyyy-MM-dd' (timezone-independent).
  static String dayStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 'yyyy-MM-dd' → local midnight on the receiving device.
  static DateTime parseDay(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static Uint8List encode(VaultData v) {
    final json = jsonEncode({
      'v': version,
      'habits': v.habits.map(habitJson).toList(),
      'entries': v.entries.map(entryJson).toList(),
      'challenges': v.challenges.map(challengeJson).toList(),
      'challengeHabits': v.challengeHabits.map(chLinkJson).toList(),
      'journals': v.journals.map(journalJson).toList(),
      // Added mid-v2: a pre-tasks client re-uploads a vault WITHOUT this key
      // (it doesn't round-trip unknown keys), but LWW re-merges tasks back in
      // from any device that has them, so nothing is lost — the vault just
      // flaps until every device is updated (auto-update makes that quick).
      'tasks': v.tasks.map(taskJson).toList(),
      'keyValues': [
        for (final kv in v.keyValues)
          if (!kLocalOnlyKeys.contains(kv.key)) kvJson(kv)
      ],
    });
    return Uint8List.fromList(gzip.encode(utf8.encode(json)));
  }

  static VaultData decode(Uint8List bytes) {
    final m =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    final v = (m['v'] as num?)?.toInt() ?? 0;
    if (v > version) throw VaultTooNewException(v);
    if (v < version) {
      throw FormatException('Unsupported vault version $v (expected $version)');
    }
    // Tolerant per-record decode: a malformed row is dropped, the rest of
    // the vault survives. LWW means a dropped row is re-filled from
    // whichever device still holds a good copy on its next push.
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) {
      final out = <T>[];
      for (final e in (m[key] as List?) ?? const []) {
        try {
          out.add(f(e as Map<String, dynamic>));
        } catch (_) {/* skip garbage record */}
      }
      return out;
    }

    return VaultData(
      habits: list('habits', habitFrom),
      entries: list('entries', entryFrom),
      challenges: list('challenges', challengeFrom),
      challengeHabits: list('challengeHabits', chLinkFrom),
      journals: list('journals', journalFrom),
      tasks: list('tasks', taskFrom),
      keyValues: list('keyValues', kvFrom)
          .where((kv) => !kLocalOnlyKeys.contains(kv.key))
          .toList(),
    );
  }

  /// Canonical JSON for one row — used by the merge for deterministic
  /// tie-breaking and change detection. Key order is fixed by construction.
  static String canonical(Map<String, dynamic> rowJson) => jsonEncode(rowJson);

  // ---- Habit ----
  static Map<String, dynamic> habitJson(Habit h) => {
        'id': h.id, 'name': h.name, 'type': h.type, 'color': h.colorValue,
        'icon': h.iconCodePoint, 'cat': h.category, 'target': h.targetValue,
        'unit': h.unit, 'created': _ms(h.createdAt), 'arch': h.archived,
        'sort': h.sortOrder,
        'del': h.deletedAt == null ? null : _ms(h.deletedAt!),
        'up': h.updatedAtMs,
        'sk': h.scheduleKind, 'sm': h.scheduleMask, 'rem': h.reminderMinutes,
      };
  static Habit habitFrom(Map<String, dynamic> m) => Habit(
        id: m['id'] as String, name: m['name'] as String, type: m['type'] as int,
        colorValue: m['color'] as int, iconCodePoint: m['icon'] as int,
        category: m['cat'] as String?, targetValue: (m['target'] as num?)?.toDouble(),
        unit: m['unit'] as String?, createdAt: _dt(m['created']),
        archived: m['arch'] as bool, sortOrder: m['sort'] as int,
        deletedAt: m['del'] == null ? null : _dt(m['del']),
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
        // Fields added in schema v6 — older vaults omit them.
        scheduleKind: (m['sk'] as num?)?.toInt() ?? 0,
        scheduleMask: (m['sm'] as num?)?.toInt() ?? 0,
        reminderMinutes: (m['rem'] as num?)?.toInt(),
      );

  // ---- HabitEntry ----
  static Map<String, dynamic> entryJson(HabitEntry e) => {
        'id': e.id, 'habitId': e.habitId, 'day': dayStr(e.date),
        'value': e.value, 'completed': e.completed, 'note': e.note,
        'created': _ms(e.createdAt), 'del': e.deleted, 'up': e.updatedAtMs,
      };
  static HabitEntry entryFrom(Map<String, dynamic> m) => HabitEntry(
        id: m['id'] as String, habitId: m['habitId'] as String,
        date: parseDay(m['day'] as String),
        value: (m['value'] as num).toDouble(), completed: m['completed'] as bool,
        note: m['note'] as String?, createdAt: _dt(m['created']),
        deleted: m['del'] as bool? ?? false,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
      );

  // ---- Challenge ----
  static Map<String, dynamic> challengeJson(Challenge c) => {
        'id': c.id, 'name': c.name, 'desc': c.description,
        'start': dayStr(c.startDate), 'end': dayStr(c.endDate),
        'mode': c.mode, 'misses': c.allowedMisses, 'color': c.colorValue,
        'icon': c.iconCodePoint, 'created': _ms(c.createdAt), 'arch': c.archived,
        'del': c.deleted, 'up': c.updatedAtMs,
      };
  static Challenge challengeFrom(Map<String, dynamic> m) => Challenge(
        id: m['id'] as String, name: m['name'] as String,
        description: m['desc'] as String?,
        startDate: parseDay(m['start'] as String),
        endDate: parseDay(m['end'] as String), mode: m['mode'] as int,
        allowedMisses: m['misses'] as int, colorValue: m['color'] as int,
        iconCodePoint: m['icon'] as int?, createdAt: _dt(m['created']),
        archived: m['arch'] as bool,
        deleted: m['del'] as bool? ?? false,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
      );

  // ---- ChallengeHabit ----
  static Map<String, dynamic> chLinkJson(ChallengeHabit c) => {
        'id': c.id, 'challengeId': c.challengeId, 'habitId': c.habitId,
        'mandatory': c.mandatory, 'del': c.deleted, 'up': c.updatedAtMs,
      };
  static ChallengeHabit chLinkFrom(Map<String, dynamic> m) => ChallengeHabit(
        id: m['id'] as String, challengeId: m['challengeId'] as String,
        habitId: m['habitId'] as String, mandatory: m['mandatory'] as bool,
        deleted: m['del'] as bool? ?? false,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
      );

  // ---- JournalEntry ----
  static Map<String, dynamic> journalJson(JournalEntry j) => {
        'id': j.id, 'kind': j.kind, 'title': j.title, 'cipher': _b64(j.cipher),
        'nonce': _b64(j.nonce), 'mac': _b64(j.mac), 'created': _ms(j.createdAt),
        'updated': _ms(j.updatedAt), 'arch': j.archived,
        'del': j.deleted, 'up': j.updatedAtMs,
      };
  static JournalEntry journalFrom(Map<String, dynamic> m) => JournalEntry(
        id: m['id'] as String, kind: m['kind'] as int, title: m['title'] as String?,
        cipher: _unb64(m['cipher']), nonce: _unb64(m['nonce']), mac: _unb64(m['mac']),
        createdAt: _dt(m['created']), updatedAt: _dt(m['updated']),
        archived: m['arch'] as bool,
        deleted: m['del'] as bool? ?? false,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
      );

  // ---- Task ----
  static Map<String, dynamic> taskJson(Task t) => {
        'id': t.id, 'title': t.title, 'notes': t.notes,
        'due': t.dueDate == null ? null : dayStr(t.dueDate!),
        'dueMin': t.dueMinutes, 'prio': t.priority, 'done': t.done,
        'doneAt': t.doneAt == null ? null : _ms(t.doneAt!),
        'created': _ms(t.createdAt), 'sort': t.sortOrder,
        'del': t.deleted, 'up': t.updatedAtMs,
      };
  static Task taskFrom(Map<String, dynamic> m) => Task(
        id: m['id'] as String, title: m['title'] as String,
        notes: m['notes'] as String?,
        dueDate: m['due'] == null ? null : parseDay(m['due'] as String),
        dueMinutes: (m['dueMin'] as num?)?.toInt(),
        priority: (m['prio'] as num?)?.toInt() ?? 1,
        done: m['done'] as bool? ?? false,
        doneAt: m['doneAt'] == null ? null : _dt(m['doneAt']),
        createdAt: _dt(m['created']),
        sortOrder: (m['sort'] as num?)?.toInt() ?? 0,
        deleted: m['del'] as bool? ?? false,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0,
      );

  // ---- KeyValue ----
  static Map<String, dynamic> kvJson(KeyValue kv) =>
      {'k': kv.key, 'v': kv.value, 'up': kv.updatedAtMs};
  static KeyValue kvFrom(Map<String, dynamic> m) => KeyValue(
        key: m['k'] as String, value: m['v'] as String,
        updatedAtMs: (m['up'] as num?)?.toInt() ?? 0);
}
