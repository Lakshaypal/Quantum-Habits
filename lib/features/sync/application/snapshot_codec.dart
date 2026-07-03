import 'dart:convert';
import 'dart:typed_data';

import '../../../core/db/database.dart';

/// KeyValue keys that are device-local and must NOT travel in a snapshot
/// (Supabase config, sync salt, device id, sync bookkeeping).
const kSyncLocalKeys = <String>{
  'supabase_url',
  'supabase_anon_key',
  'sync_salt',
  'device_id',
  'last_synced_at',
};

/// An in-memory copy of all syncable data.
class Snapshot {
  final List<Habit> habits;
  final List<HabitEntry> entries;
  final List<Challenge> challenges;
  final List<ChallengeHabit> challengeHabits;
  final List<JournalEntry> journals;
  final List<KeyValue> keyValues;
  const Snapshot({
    required this.habits,
    required this.entries,
    required this.challenges,
    required this.challengeHabits,
    required this.journals,
    required this.keyValues,
  });
}

/// JSON (de)serialization of a [Snapshot]. Timestamps are epoch-ms; blobs are
/// base64 — both round-trip-safe across platforms.
abstract final class SnapshotCodec {
  static int _ms(DateTime d) => d.millisecondsSinceEpoch;
  static DateTime _dt(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
  static String _b64(Uint8List b) => base64.encode(b);
  static Uint8List _unb64(Object? v) => Uint8List.fromList(base64.decode(v as String));

  static String encode(Snapshot s) => jsonEncode({
        'v': 1,
        'habits': s.habits.map(_habit).toList(),
        'entries': s.entries.map(_entry).toList(),
        'challenges': s.challenges.map(_challenge).toList(),
        'challengeHabits': s.challengeHabits.map(_chLink).toList(),
        'journals': s.journals.map(_journal).toList(),
        'keyValues': [
          for (final kv in s.keyValues)
            if (!kSyncLocalKeys.contains(kv.key)) {'k': kv.key, 'v': kv.value}
        ],
      });

  static Snapshot decode(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((m[key] as List?) ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();
    return Snapshot(
      habits: list('habits', _habitFrom),
      entries: list('entries', _entryFrom),
      challenges: list('challenges', _challengeFrom),
      challengeHabits: list('challengeHabits', _chLinkFrom),
      journals: list('journals', _journalFrom),
      keyValues: list('keyValues', (e) => KeyValue(key: e['k'] as String, value: e['v'] as String)),
    );
  }

  // ---- Habit ----
  static Map<String, dynamic> _habit(Habit h) => {
        'id': h.id, 'name': h.name, 'type': h.type, 'color': h.colorValue,
        'icon': h.iconCodePoint, 'cat': h.category, 'target': h.targetValue,
        'unit': h.unit, 'created': _ms(h.createdAt), 'arch': h.archived, 'sort': h.sortOrder,
      };
  static Habit _habitFrom(Map<String, dynamic> m) => Habit(
        id: m['id'] as String, name: m['name'] as String, type: m['type'] as int,
        colorValue: m['color'] as int, iconCodePoint: m['icon'] as int,
        category: m['cat'] as String?, targetValue: (m['target'] as num?)?.toDouble(),
        unit: m['unit'] as String?, createdAt: _dt(m['created']),
        archived: m['arch'] as bool, sortOrder: m['sort'] as int,
      );

  // ---- HabitEntry ----
  static Map<String, dynamic> _entry(HabitEntry e) => {
        'id': e.id, 'habitId': e.habitId, 'date': _ms(e.date), 'value': e.value,
        'completed': e.completed, 'note': e.note, 'created': _ms(e.createdAt),
      };
  static HabitEntry _entryFrom(Map<String, dynamic> m) => HabitEntry(
        id: m['id'] as String, habitId: m['habitId'] as String, date: _dt(m['date']),
        value: (m['value'] as num).toDouble(), completed: m['completed'] as bool,
        note: m['note'] as String?, createdAt: _dt(m['created']),
      );

  // ---- Challenge ----
  static Map<String, dynamic> _challenge(Challenge c) => {
        'id': c.id, 'name': c.name, 'desc': c.description, 'start': _ms(c.startDate),
        'end': _ms(c.endDate), 'mode': c.mode, 'misses': c.allowedMisses,
        'color': c.colorValue, 'icon': c.iconCodePoint, 'created': _ms(c.createdAt), 'arch': c.archived,
      };
  static Challenge _challengeFrom(Map<String, dynamic> m) => Challenge(
        id: m['id'] as String, name: m['name'] as String, description: m['desc'] as String?,
        startDate: _dt(m['start']), endDate: _dt(m['end']), mode: m['mode'] as int,
        allowedMisses: m['misses'] as int, colorValue: m['color'] as int,
        iconCodePoint: m['icon'] as int?, createdAt: _dt(m['created']), archived: m['arch'] as bool,
      );

  // ---- ChallengeHabit ----
  static Map<String, dynamic> _chLink(ChallengeHabit c) =>
      {'id': c.id, 'challengeId': c.challengeId, 'habitId': c.habitId, 'mandatory': c.mandatory};
  static ChallengeHabit _chLinkFrom(Map<String, dynamic> m) => ChallengeHabit(
        id: m['id'] as String, challengeId: m['challengeId'] as String,
        habitId: m['habitId'] as String, mandatory: m['mandatory'] as bool,
      );

  // ---- JournalEntry ----
  static Map<String, dynamic> _journal(JournalEntry j) => {
        'id': j.id, 'kind': j.kind, 'title': j.title, 'cipher': _b64(j.cipher),
        'nonce': _b64(j.nonce), 'mac': _b64(j.mac), 'created': _ms(j.createdAt),
        'updated': _ms(j.updatedAt), 'arch': j.archived,
      };
  static JournalEntry _journalFrom(Map<String, dynamic> m) => JournalEntry(
        id: m['id'] as String, kind: m['kind'] as int, title: m['title'] as String?,
        cipher: _unb64(m['cipher']), nonce: _unb64(m['nonce']), mac: _unb64(m['mac']),
        createdAt: _dt(m['created']), updatedAt: _dt(m['updated']), archived: m['arch'] as bool,
      );
}
