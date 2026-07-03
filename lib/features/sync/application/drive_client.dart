import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'google_auth.dart';

/// Metadata for the vault file as Drive sees it. `version` increments on
/// every content change server-side — the cheap "did anything change?" probe.
class DriveFileInfo {
  final String id;
  final String version;
  final String? md5;
  const DriveFileInfo(this.id, this.version, this.md5);
}

class DriveException implements Exception {
  final String message;
  final bool isAuthError;
  DriveException(this.message, {this.isAuthError = false});
  @override
  String toString() => message;
}

/// Minimal Google Drive v3 client scoped to the hidden appDataFolder — the
/// app-private space in the user's own Drive. No servers of ours involved.
class DriveClient {
  static const _vaultName = 'quantum_habits_vault.qh2';
  static const _base = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  final GoogleCredentials _creds;
  DriveClient(this._creds);

  Future<Map<String, String>> _headers() async =>
      {'Authorization': 'Bearer ${await GoogleAuth.accessToken(_creds)}'};

  /// Finds the vault file, or null if this account has never synced.
  Future<DriveFileInfo?> findVault() async {
    final uri = Uri.parse('$_base/files').replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name = '$_vaultName' and trashed = false",
      'fields': 'files(id,version,md5Checksum)',
      'pageSize': '10',
    });
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    final files = (jsonDecode(res.body)['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    final f = files.first as Map<String, dynamic>;
    return DriveFileInfo(
        f['id'] as String, '${f['version']}', f['md5Checksum'] as String?);
  }

  /// Cheap change probe for a known file id.
  Future<DriveFileInfo> stat(String fileId) async {
    final uri = Uri.parse('$_base/files/$fileId')
        .replace(queryParameters: {'fields': 'id,version,md5Checksum'});
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    final f = jsonDecode(res.body) as Map<String, dynamic>;
    return DriveFileInfo(
        f['id'] as String, '${f['version']}', f['md5Checksum'] as String?);
  }

  Future<Uint8List> download(String fileId) async {
    final uri = Uri.parse('$_base/files/$fileId').replace(
        queryParameters: {'alt': 'media'});
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return res.bodyBytes;
  }

  /// Creates the vault file in appDataFolder; returns fresh metadata.
  Future<DriveFileInfo> create(Uint8List bytes) async {
    const boundary = 'qh_vault_boundary';
    final meta = jsonEncode({
      'name': _vaultName,
      'parents': ['appDataFolder'],
    });
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: application/octet-stream\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final uri = Uri.parse('$_upload/files').replace(queryParameters: {
      'uploadType': 'multipart',
      'fields': 'id,version,md5Checksum',
    });
    final res = await _send(() async => http.post(uri,
        headers: {
          ...await _headers(),
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: body.toBytes()));
    final f = jsonDecode(res.body) as Map<String, dynamic>;
    return DriveFileInfo(
        f['id'] as String, '${f['version']}', f['md5Checksum'] as String?);
  }

  /// Replaces the vault file's content; returns fresh metadata.
  Future<DriveFileInfo> update(String fileId, Uint8List bytes) async {
    final uri = Uri.parse('$_upload/files/$fileId').replace(queryParameters: {
      'uploadType': 'media',
      'fields': 'id,version,md5Checksum',
    });
    final res = await _send(() async => http.patch(uri,
        headers: {
          ...await _headers(),
          'Content-Type': 'application/octet-stream',
        },
        body: bytes));
    final f = jsonDecode(res.body) as Map<String, dynamic>;
    return DriveFileInfo(
        f['id'] as String, '${f['version']}', f['md5Checksum'] as String?);
  }

  Future<http.Response> _send(Future<http.Response> Function() go) async {
    final http.Response res;
    try {
      res = await go().timeout(const Duration(seconds: 60));
    } on SocketException {
      throw DriveException('Offline — will retry automatically.');
    } on TimeoutException {
      throw DriveException('Google Drive took too long to respond.');
    } on GoogleAuthException catch (e) {
      throw DriveException(e.message, isAuthError: true);
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw DriveException(
          'Google Drive access was denied (HTTP ${res.statusCode}) — '
          'reconnect your Drive.',
          isAuthError: res.statusCode == 401);
    }
    if (res.statusCode == 404) {
      throw DriveException('Vault file missing on Drive.', isAuthError: false);
    }
    if (res.statusCode >= 400) {
      throw DriveException('Google Drive error HTTP ${res.statusCode}.');
    }
    return res;
  }
}
