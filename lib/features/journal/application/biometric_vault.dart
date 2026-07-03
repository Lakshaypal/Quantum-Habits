import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'journal_crypto.dart';

/// Optional convenience: remember the derived key in the platform keychain,
/// gated by biometrics / device auth. Everything is best-effort and wrapped —
/// if biometrics or secure storage are unavailable, the journal silently falls
/// back to passphrase-only and nothing breaks.
class BiometricVaultService {
  static const _storage = FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();
  static const _kKey = 'journal_key_bytes';

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStoredKey() async {
    try {
      return (await _storage.read(key: _kKey)) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> remember(JournalVault vault) async {
    try {
      final bytes = await (await vault.key).extractBytes();
      await _storage.write(key: _kKey, value: base64.encode(bytes));
    } catch (_) {/* best-effort */}
  }

  Future<void> forget() async {
    try {
      await _storage.delete(key: _kKey);
    } catch (_) {/* best-effort */}
  }

  /// Authenticates, then rebuilds the vault from the stored key. Null on any
  /// failure or cancellation.
  Future<JournalVault?> unlockWithBiometrics() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your journal',
        biometricOnly: false,
      );
      if (!ok) return null;
      final stored = await _storage.read(key: _kKey);
      if (stored == null) return null;
      return JournalVault(SecretKey(base64.decode(stored)));
    } catch (_) {
      return null;
    }
  }
}
