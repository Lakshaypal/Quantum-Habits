import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/db/database.dart';

const _verifyPlaintext = 'quantum-habits-journal-verify-v1';

/// Holds the derived key in memory and performs AES-256-GCM on entry bodies.
/// The key is never persisted in plaintext; closing the app (or locking)
/// drops it.
class JournalVault {
  final SecretKey _key;
  final AesGcm _algo = AesGcm.with256bits();
  JournalVault(this._key);

  Future<SecretKey> get key async => _key;

  Future<({Uint8List nonce, Uint8List cipher, Uint8List mac})> encryptText(String plain) async {
    final box = await _algo.encrypt(utf8.encode(plain), secretKey: _key);
    return (
      nonce: Uint8List.fromList(box.nonce),
      cipher: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<String> decryptText(List<int> nonce, List<int> cipher, List<int> mac) async {
    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final clear = await _algo.decrypt(box, secretKey: _key);
    return utf8.decode(clear);
  }
}

/// Sets up the journal passphrase, derives the key (PBKDF2-HMAC-SHA256), and
/// validates it against an encrypted verifier token.
class JournalKeyService {
  final AppDatabase _db;
  JournalKeyService(this._db);

  final Pbkdf2 _kdf =
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256);
  final AesGcm _algo = AesGcm.with256bits();

  static const _kSalt = 'journal_salt';
  static const _kVNonce = 'journal_v_nonce';
  static const _kVCipher = 'journal_v_cipher';
  static const _kVMac = 'journal_v_mac';

  Future<bool> hasPassphrase() async => (await _db.getKV(_kSalt)) != null;

  Future<SecretKey> _derive(String passphrase, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  /// First-time setup: persist a random salt + encrypted verifier, return the
  /// unlocked vault.
  Future<JournalVault> setupPassphrase(String passphrase) async {
    final salt = _randomBytes(16);
    final key = await _derive(passphrase, salt);
    final box = await _algo.encrypt(utf8.encode(_verifyPlaintext), secretKey: key);
    await _db.setKV(_kSalt, base64.encode(salt));
    await _db.setKV(_kVNonce, base64.encode(box.nonce));
    await _db.setKV(_kVCipher, base64.encode(box.cipherText));
    await _db.setKV(_kVMac, base64.encode(box.mac.bytes));
    return JournalVault(key);
  }

  /// Returns a vault when the passphrase is correct; null otherwise (the GCM
  /// MAC check on the verifier rejects a wrong passphrase).
  Future<JournalVault?> unlock(String passphrase) async {
    final saltB = await _db.getKV(_kSalt);
    if (saltB == null) return null;
    final key = await _derive(passphrase, base64.decode(saltB));
    try {
      final box = SecretBox(
        base64.decode((await _db.getKV(_kVCipher))!),
        nonce: base64.decode((await _db.getKV(_kVNonce))!),
        mac: Mac(base64.decode((await _db.getKV(_kVMac))!)),
      );
      final clear = utf8.decode(await _algo.decrypt(box, secretKey: key));
      return clear == _verifyPlaintext ? JournalVault(key) : null;
    } catch (_) {
      return null;
    }
  }
}
