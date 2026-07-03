import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;
import 'snapshot_codec.dart';
import 'sync_crypto.dart';

/// Whether Supabase.initialize has run this process (it may only run once).
bool supabaseInitialized = false;

/// Initializes Supabase from stored config, if present. Safe to call repeatedly.
Future<bool> initSupabaseFromConfig(AppDatabase db) async {
  if (supabaseInitialized) return true;
  final url = await db.getKV('supabase_url');
  final anonKey = await db.getKV('supabase_anon_key');
  if (url == null || anonKey == null || url.isEmpty || anonKey.isEmpty) return false;
  try {
    // ignore: deprecated_member_use  (anonKey accepts the JWT users copy)
    await Supabase.initialize(url: url, anonKey: anonKey);
    supabaseInitialized = true;
    return true;
  } catch (_) {
    return false;
  }
}

enum SyncOutcome { pushed, pulled, upToDate }

class SyncResult {
  final SyncOutcome outcome;
  final String message;
  const SyncResult(this.outcome, this.message);
}

final syncServiceProvider =
    Provider<SyncService>((ref) => SyncService(ref.watch(databaseProvider)));

/// Whether config exists (drives the settings UI). Invalidated after saving.
final syncConfiguredProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final url = await db.getKV('supabase_url');
  final key = await db.getKV('supabase_anon_key');
  return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
});

/// The sync passphrase for this session (in-memory; never persisted).
class SyncPassphrase extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String value) => state = value;
}

final syncPassphraseProvider =
    NotifierProvider<SyncPassphrase, String?>(SyncPassphrase.new);

/// End-to-end-encrypted, offline-first cloud sync over Supabase using a
/// whole-vault snapshot with last-sync-wins resolution. Supabase only ever
/// stores opaque ciphertext + a (non-secret) PBKDF2 salt.
class SyncService {
  final AppDatabase _db;
  SyncService(this._db);
  static const _uuid = Uuid();

  bool get isInitialized => supabaseInitialized;
  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => supabaseInitialized ? _client.auth.currentUser : null;
  bool get isSignedIn => currentUser != null;

  Future<void> saveConfig(String url, String anonKey) async {
    await _db.setKV('supabase_url', url.trim());
    await _db.setKV('supabase_anon_key', anonKey.trim());
  }

  Future<bool> ensureInitialized() => initSupabaseFromConfig(_db);

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> signUp(String email, String password) =>
      _client.auth.signUp(email: email.trim(), password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<String> _deviceId() async {
    var id = await _db.getKV('device_id');
    if (id == null) {
      id = _uuid.v4();
      await _db.setKV('device_id', id);
    }
    return id;
  }

  Future<Snapshot> _localSnapshot() async => Snapshot(
        habits: await _db.allHabits(),
        entries: await _db.allHabitEntries(),
        challenges: await _db.allChallenges(),
        challengeHabits: await _db.allChallengeHabits(),
        journals: await _db.allJournalEntries(),
        keyValues: await _db.allKeyValues(),
      );

  Future<void> _applySnapshot(Snapshot s) => _db.importSnapshot(
        habitRows: s.habits,
        entryRows: s.entries,
        challengeRows: s.challenges,
        challengeHabitRows: s.challengeHabits,
        journalRows: s.journals,
        keyValueRows: s.keyValues,
      );

  Future<void> _push(SyncCrypto crypto, String saltB64, DateTime when) async {
    final blob = await crypto.encrypt(SnapshotCodec.encode(await _localSnapshot()));
    await _client.from('vault').upsert({
      'user_id': currentUser!.id,
      'payload': blob.toJson(),
      'salt': saltB64,
      'updated_at': when.toUtc().toIso8601String(),
      'device_id': await _deviceId(),
    });
    await _db.setKV('sync_salt', saltB64);
    await _db.setKV('last_synced_at', '${when.millisecondsSinceEpoch}');
  }

  /// Pulls the remote vault, applies it if a newer device pushed it, otherwise
  /// pushes the local snapshot. Throws if not signed in.
  Future<SyncResult> syncNow(String passphrase) async {
    if (!isSignedIn) throw StateError('Not signed in');
    final now = DateTime.now();
    final myDevice = await _deviceId();
    final lastSynced = int.tryParse(await _db.getKV('last_synced_at') ?? '') ?? 0;

    final row = await _client
        .from('vault')
        .select()
        .eq('user_id', currentUser!.id)
        .maybeSingle();

    if (row == null) {
      final salt = SyncCrypto.randomSalt();
      final crypto = await SyncCrypto.derive(passphrase, salt);
      await _push(crypto, base64.encode(salt), now);
      return const SyncResult(SyncOutcome.pushed, 'Backed up to the cloud (first sync).');
    }

    final saltB64 = row['salt'] as String;
    final crypto = await SyncCrypto.derive(passphrase, base64.decode(saltB64));
    final remoteUpdated = DateTime.parse(row['updated_at'] as String);
    final remoteDevice = row['device_id'] as String;

    final remoteNewer = remoteUpdated.millisecondsSinceEpoch > lastSynced;
    if (remoteNewer && remoteDevice != myDevice) {
      final blob = EncryptedBlob.fromJson(Map<String, dynamic>.from(row['payload'] as Map));
      final json = await crypto.decrypt(blob); // wrong passphrase -> throws (MAC)
      await _applySnapshot(SnapshotCodec.decode(json));
      await _db.setKV('sync_salt', saltB64);
      await _db.setKV('last_synced_at', '${remoteUpdated.millisecondsSinceEpoch}');
      return const SyncResult(SyncOutcome.pulled, 'Pulled the latest from another device.');
    }

    await _push(crypto, saltB64, now);
    return const SyncResult(SyncOutcome.pushed, 'Local changes backed up.');
  }
}
