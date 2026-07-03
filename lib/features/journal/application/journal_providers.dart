import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;
import '../data/journal_kind.dart';
import 'biometric_vault.dart';
import 'journal_crypto.dart';

const _uuid = Uuid();

final journalKeyServiceProvider =
    Provider<JournalKeyService>((ref) => JournalKeyService(ref.watch(databaseProvider)));

final biometricVaultProvider = Provider<BiometricVaultService>((ref) => BiometricVaultService());

final hasPassphraseProvider =
    FutureProvider<bool>((ref) => ref.watch(journalKeyServiceProvider).hasPassphrase());

/// The unlocked vault, or null when the journal is locked. Cleared on lock /
/// app restart, and auto-locked the moment the app leaves the foreground so
/// whoever picks up the device lands on the lock screen.
class JournalSession extends Notifier<JournalVault?> {
  AppLifecycleListener? _lifecycle;

  @override
  JournalVault? build() {
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    _lifecycle ??= AppLifecycleListener(onHide: lock, onPause: lock);
    return null;
  }

  void open(JournalVault vault) => state = vault;
  void lock() => state = null;
}

final journalSessionProvider =
    NotifierProvider<JournalSession, JournalVault?>(JournalSession.new);

final journalEntriesProvider = StreamProvider<List<JournalEntry>>(
    (ref) => ref.watch(databaseProvider).watchJournalEntries());

/// A journal entry decrypted for display. Title + body live inside the
/// ciphertext, so nothing readable is stored on disk.
class DecryptedEntry {
  final JournalEntry meta;
  final String title;
  final String body;
  const DecryptedEntry(this.meta, this.title, this.body);

  JournalKind get kind => JournalKindX.fromIndex(meta.kind);
}

/// Decrypts all active entries when the vault is open. Re-runs when entries or
/// the unlock state change.
final decryptedJournalProvider = FutureProvider<List<DecryptedEntry>>((ref) async {
  final vault = ref.watch(journalSessionProvider);
  if (vault == null) return const [];
  final entries = ref.watch(journalEntriesProvider).asData?.value ?? const [];
  final out = <DecryptedEntry>[];
  for (final e in entries) {
    try {
      final plain = await vault.decryptText(e.nonce, e.cipher, e.mac);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      out.add(DecryptedEntry(e, (map['t'] as String?) ?? '', (map['b'] as String?) ?? ''));
    } catch (_) {/* skip entries this key can't open */}
  }
  return out;
});

final journalServiceProvider =
    Provider<JournalService>((ref) => JournalService(ref.watch(databaseProvider)));

class JournalService {
  final AppDatabase _db;
  JournalService(this._db);

  Future<void> save({
    String? id,
    required JournalKind kind,
    String? title,
    required String body,
    required JournalVault vault,
    DateTime? createdAt,
  }) async {
    final payload = jsonEncode({'t': title ?? '', 'b': body});
    final enc = await vault.encryptText(payload);
    final now = DateTime.now();
    await _db.upsertJournalEntry(JournalEntriesCompanion(
      id: Value(id ?? _uuid.v4()),
      kind: Value(kind.index),
      title: const Value(null), // title is encrypted inside the blob
      cipher: Value(enc.cipher),
      nonce: Value(enc.nonce),
      mac: Value(enc.mac),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    ));
  }

  Future<void> archive(String id) => _db.setJournalArchived(id, true);

  /// Cryptographic destruction — the ciphertext is permanently deleted.
  Future<void> burn(String id) => _db.burnJournalEntry(id);
}
