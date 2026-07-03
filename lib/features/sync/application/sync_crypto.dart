import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM ciphertext components for a synced snapshot.
class EncryptedBlob {
  final Uint8List nonce;
  final Uint8List cipher;
  final Uint8List mac;
  const EncryptedBlob(this.nonce, this.cipher, this.mac);

  Map<String, String> toJson() => {
        'n': base64.encode(nonce),
        'c': base64.encode(cipher),
        'm': base64.encode(mac),
      };

  static EncryptedBlob fromJson(Map<String, dynamic> j) => EncryptedBlob(
        Uint8List.fromList(base64.decode(j['n'] as String)),
        Uint8List.fromList(base64.decode(j['c'] as String)),
        Uint8List.fromList(base64.decode(j['m'] as String)),
      );
}

/// End-to-end encryption for cloud sync. The key is derived from the user's
/// sync passphrase via PBKDF2 and never leaves the device — Supabase only ever
/// stores opaque ciphertext.
class SyncCrypto {
  final SecretKey _key;
  final AesGcm _algo = AesGcm.with256bits();
  SyncCrypto(this._key);

  static final Pbkdf2 _kdf =
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256);

  static Uint8List randomSalt([int n = 16]) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Future<SyncCrypto> derive(String passphrase, List<int> salt) async {
    final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    return SyncCrypto(key);
  }

  Future<EncryptedBlob> encrypt(String plain) async {
    final box = await _algo.encrypt(utf8.encode(plain), secretKey: _key);
    return EncryptedBlob(
      Uint8List.fromList(box.nonce),
      Uint8List.fromList(box.cipherText),
      Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<String> decrypt(EncryptedBlob b) async {
    final clear = await _algo.decrypt(
      SecretBox(b.cipher, nonce: b.nonce, mac: Mac(b.mac)),
      secretKey: _key,
    );
    return utf8.decode(clear);
  }
}
