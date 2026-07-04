import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../habits/application/habit_providers.dart' show databaseProvider;
import 'drive_client.dart';
import 'google_auth.dart';
import 'vault_codec.dart';
import 'vault_merge.dart';

enum SyncPhase {
  /// No Google account connected.
  disconnected,

  /// Connected; nothing in flight.
  idle,

  /// A sync round is running.
  syncing,

  /// Connected but the network is unavailable; changes queue locally.
  offline,

  /// Connected but the last round failed for a non-network reason.
  error,
}

@immutable
class SyncStatus {
  final SyncPhase phase;
  final String? email;
  final DateTime? lastSyncedAt;
  final String? message;
  final bool autoSync;
  const SyncStatus({
    this.phase = SyncPhase.disconnected,
    this.email,
    this.lastSyncedAt,
    this.message,
    this.autoSync = true,
  });

  SyncStatus copyWith({
    SyncPhase? phase,
    String? email,
    DateTime? lastSyncedAt,
    String? message,
    bool? autoSync,
    bool clearMessage = false,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        email: email ?? this.email,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: clearMessage ? null : (message ?? this.message),
        autoSync: autoSync ?? this.autoSync,
      );

  bool get connected => phase != SyncPhase.disconnected;
}

final syncEngineProvider =
    NotifierProvider<SyncEngine, SyncStatus>(SyncEngine.new);

/// Keeps this device and the user's Google Drive vault continuously
/// converged:
///  - any local mutation triggers a debounced sync (~3s after the last tap);
///  - a foreground poll (~40s) probes the vault's Drive version and pulls
///    remote changes, so edits on another device land within a minute;
///  - returning to the app syncs immediately;
///  - while offline, changes queue locally and flush on the next success.
///
/// Every round is a per-record merge (see [VaultMerge]) — there is no
/// destructive "replace" path anywhere.
class SyncEngine extends Notifier<SyncStatus> {
  static const _debounce = Duration(seconds: 3);
  static const _pollEvery = Duration(seconds: 40);
  static const _uuid = Uuid();

  AppDatabase get _db => ref.read(databaseProvider);

  GoogleCredentials? _creds;
  bool _dirty = false;
  bool _syncing = false;
  bool _rerunAfter = false;
  bool _selfWrite = false;
  bool _foreground = true;
  Timer? _debounceTimer;
  Timer? _pollTimer;
  StreamSubscription<Object?>? _dbSub;
  AppLifecycleListener? _lifecycle;

  /// Called with the rows that were applied locally after a remote pull, so
  /// feature layers can react (e.g. journal re-locks if its keys changed).
  void Function(VaultData applied)? onRemoteApplied;

  @override
  SyncStatus build() {
    ref.onDispose(_teardown);
    Future.microtask(_init);
    return const SyncStatus();
  }

  Future<void> _init() async {
    final auto = await _db.getKV('sync_auto');
    final autoSync = auto != '0';
    _creds = await GoogleAuth.stored();
    if (_creds == null) {
      state = SyncStatus(autoSync: autoSync);
      return;
    }
    final lastMs = int.tryParse(await _db.getKV('last_synced_at') ?? '');
    state = SyncStatus(
      phase: SyncPhase.idle,
      email: _creds!.email,
      autoSync: autoSync,
      lastSyncedAt:
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
    _attachTriggers();
    syncNow();
  }

  void _attachTriggers() {
    _dbSub ??= _db.tableUpdates().listen((_) {
      if (_selfWrite || !state.connected) return;
      _dirty = true;
      if (!state.autoSync) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, syncNow);
    });
    _pollTimer ??= Timer.periodic(_pollEvery, (_) {
      if (!_foreground || !state.connected || !state.autoSync) return;
      syncNow(probe: true);
    });
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        _foreground = true;
        if (state.connected && state.autoSync) syncNow();
      },
      onInactive: () => _foreground = false,
    );
  }

  void _teardown() {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _dbSub?.cancel();
    _lifecycle?.dispose();
  }

  Future<String> _deviceId() async {
    var id = await _db.getKV('device_id');
    if (id == null) {
      id = _uuid.v4();
      await _selfWriteGuard(() => _db.setKV('device_id', id!));
    }
    return id;
  }

  Future<T> _selfWriteGuard<T>(Future<T> Function() fn) async {
    _selfWrite = true;
    try {
      return await fn();
    } finally {
      _selfWrite = false;
    }
  }

  /// One-time interactive connect. The client id/secret come from the user's
  /// own Google Cloud OAuth client (docs/GOOGLE_DRIVE.md walks through it).
  Future<void> connect(String clientId, String clientSecret) async {
    final creds = await GoogleAuth.connect(clientId.trim(), clientSecret.trim());
    _creds = creds;
    await _selfWriteGuard(() => _db.setKV('gdrive_client_id', clientId.trim()));
    state = state.copyWith(
        phase: SyncPhase.idle, email: creds.email, clearMessage: true);
    _attachTriggers();
    await syncNow();
  }

  /// Disconnects this device only — data on Drive and other devices stays.
  Future<void> disconnect() async {
    await GoogleAuth.forget();
    _creds = null;
    await _selfWriteGuard(() async {
      await _db.deleteKV('drive_file_id');
      await _db.deleteKV('drive_last_version');
      await _db.deleteKV('last_synced_at');
    });
    state = SyncStatus(autoSync: state.autoSync);
  }

  Future<void> setAutoSync(bool on) async {
    await _selfWriteGuard(() => _db.setKV('sync_auto', on ? '1' : '0'));
    state = state.copyWith(autoSync: on);
    if (on && state.connected) syncNow();
  }

  /// Runs one merge round. [probe] rounds skip work when neither side moved.
  /// Concurrent calls coalesce: one runs, one rerun is queued.
  Future<void> syncNow({bool probe = false}) async {
    final creds = _creds;
    if (creds == null) return;
    if (_syncing) {
      _rerunAfter = true;
      return;
    }
    _syncing = true;
    if (!probe) state = state.copyWith(phase: SyncPhase.syncing, clearMessage: true);
    try {
      await _deviceId(); // ensure identity exists before first vault write
      final drive = DriveClient(creds);
      final knownId = await _db.getKV('drive_file_id');
      final lastVersion = await _db.getKV('drive_last_version');

      DriveFileInfo? info;
      if (knownId != null) {
        try {
          info = await drive.stat(knownId);
        } on DriveException catch (e) {
          if (e.isAuthError) rethrow;
          info = await drive.findVault(); // file vanished — rediscover
        }
      } else {
        info = await drive.findVault();
      }

      if (info == null) {
        // First sync for this account: seed the vault with local data.
        final local = await VaultData.fromDb(_db);
        final created = await drive.create(VaultCodec.encode(local));
        await _finishRound(created);
        return;
      }

      if (info.version == lastVersion && !_dirty) {
        _syncing = false;
        if (state.phase != SyncPhase.idle) {
          state = state.copyWith(phase: SyncPhase.idle);
        }
        _maybeRerun();
        return;
      }

      final local = await VaultData.fromDb(_db);
      VaultData remote;
      try {
        remote = VaultCodec.decode(await drive.download(info.id));
      } on VaultTooNewException catch (e) {
        // A newer app wrote this vault — never overwrite it from here.
        _syncing = false;
        state = state.copyWith(phase: SyncPhase.error, message: e.toString());
        _maybeRerun();
        return;
      } on FormatException {
        // Unreadable/corrupt vault: self-heal by re-seeding from local data
        // (local is never mutated on this path, so nothing can be lost here).
        final created = await drive.update(info.id, VaultCodec.encode(local));
        await _finishRound(created);
        return;
      }

      final result = VaultMerge.merge(local, remote);
      if (result.localChanged) {
        await _selfWriteGuard(() => _db.applyMergedRows(
              habitRows: result.toWriteLocal.habits,
              entryRows: result.toWriteLocal.entries,
              challengeRows: result.toWriteLocal.challenges,
              challengeHabitRows: result.toWriteLocal.challengeHabits,
              journalRows: result.toWriteLocal.journals,
              keyValueRows: result.toWriteLocal.keyValues,
            ));
        onRemoteApplied?.call(result.toWriteLocal);
      }
      var latest = info;
      if (result.remoteChanged) {
        latest = await drive.update(info.id, VaultCodec.encode(result.merged));
      }
      await _finishRound(latest);
    } on DriveException catch (e) {
      _syncing = false;
      state = state.copyWith(
          phase: e.message.startsWith('Offline')
              ? SyncPhase.offline
              : SyncPhase.error,
          message: e.message);
    } on GoogleAuthException catch (e) {
      _syncing = false;
      state = state.copyWith(phase: SyncPhase.error, message: e.message);
    } catch (e) {
      _syncing = false;
      state = state.copyWith(
          phase: SyncPhase.error, message: 'Sync failed: $e');
    }
  }

  Future<void> _finishRound(DriveFileInfo info) async {
    final now = DateTime.now();
    _dirty = false;
    await _selfWriteGuard(() async {
      await _db.setKV('drive_file_id', info.id);
      await _db.setKV('drive_last_version', info.version);
      await _db.setKV('last_synced_at', '${now.millisecondsSinceEpoch}');
    });
    _syncing = false;
    state = state.copyWith(
        phase: SyncPhase.idle, lastSyncedAt: now, clearMessage: true);
    _maybeRerun();
  }

  void _maybeRerun() {
    if (_rerunAfter) {
      _rerunAfter = false;
      Future.microtask(syncNow);
    }
  }
}
