import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Persisted OAuth state for the connected Google account. Client id/secret
/// come from the user's own Google Cloud "Desktop app" OAuth client — Google
/// explicitly treats installed-app secrets as non-confidential, which is why
/// this flow works without any server of ours.
class GoogleCredentials {
  final String clientId;
  final String clientSecret;
  final String refreshToken;
  String accessToken;
  int accessExpiryMs;
  final String email;

  GoogleCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.accessToken,
    required this.accessExpiryMs,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'refreshToken': refreshToken,
        'accessToken': accessToken,
        'accessExpiryMs': accessExpiryMs,
        'email': email,
      };

  static GoogleCredentials fromJson(Map<String, dynamic> m) => GoogleCredentials(
        clientId: m['clientId'] as String,
        clientSecret: m['clientSecret'] as String,
        refreshToken: m['refreshToken'] as String,
        accessToken: m['accessToken'] as String? ?? '',
        accessExpiryMs: (m['accessExpiryMs'] as num?)?.toInt() ?? 0,
        email: m['email'] as String? ?? '',
      );
}

class GoogleAuthException implements Exception {
  final String message;
  GoogleAuthException(this.message);
  @override
  String toString() => message;
}

/// OAuth 2.0 "installed app" flow with a loopback redirect + PKCE.
/// Identical on macOS, Windows and Android: the app listens on an ephemeral
/// `http://127.0.0.1` port, opens the consent page in the system browser, and
/// catches the redirect locally.
class GoogleAuth {
  static const _storageKey = 'gdrive_credentials';
  static const _scopes =
      'https://www.googleapis.com/auth/drive.appdata openid email';
  static const _storage = FlutterSecureStorage();

  static Future<GoogleCredentials?> stored() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    try {
      return GoogleCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> persist(GoogleCredentials c) =>
      _storage.write(key: _storageKey, value: jsonEncode(c.toJson()));

  static Future<void> forget() => _storage.delete(key: _storageKey);

  /// Runs the interactive consent flow. Returns persisted credentials.
  static Future<GoogleCredentials> connect(
      String clientId, String clientSecret) async {
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirect = 'http://127.0.0.1:${server.port}';
      final authUrl = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth')
          .replace(queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': _scopes,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw GoogleAuthException('Could not open the browser for sign-in.');
      }

      final code = await _waitForCode(server)
          .timeout(const Duration(minutes: 5), onTimeout: () {
        throw GoogleAuthException(
            'Sign-in timed out — no response from the browser in 5 minutes.');
      });

      final tokens = await _post('https://oauth2.googleapis.com/token', {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirect,
      });

      final refreshToken = tokens['refresh_token'] as String?;
      if (refreshToken == null) {
        throw GoogleAuthException(
            'Google did not return a refresh token. Remove this app\'s access '
            'at myaccount.google.com/permissions and connect again.');
      }
      final creds = GoogleCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        accessToken: tokens['access_token'] as String,
        accessExpiryMs: _expiry(tokens),
        email: _emailFromIdToken(tokens['id_token'] as String?) ?? '',
      );
      await persist(creds);
      return creds;
    } finally {
      await server.close(force: true);
    }
  }

  /// Returns a valid access token, refreshing if within a minute of expiry.
  static Future<String> accessToken(GoogleCredentials creds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (creds.accessToken.isNotEmpty && now < creds.accessExpiryMs - 60000) {
      return creds.accessToken;
    }
    final tokens = await _post('https://oauth2.googleapis.com/token', {
      'client_id': creds.clientId,
      'client_secret': creds.clientSecret,
      'refresh_token': creds.refreshToken,
      'grant_type': 'refresh_token',
    });
    creds.accessToken = tokens['access_token'] as String;
    creds.accessExpiryMs = _expiry(tokens);
    await persist(creds);
    return creds.accessToken;
  }

  static Future<String> _waitForCode(HttpServer server) async {
    await for (final req in server) {
      final code = req.uri.queryParameters['code'];
      final error = req.uri.queryParameters['error'];
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(_landingHtml(ok: code != null));
      await req.response.close();
      if (code != null) return code;
      if (error != null) {
        throw GoogleAuthException(error == 'access_denied'
            ? 'Sign-in was cancelled in the browser.'
            : 'Google sign-in failed: $error');
      }
      // Ignore stray requests (favicon etc.) and keep waiting.
    }
    throw GoogleAuthException('Sign-in window closed before completing.');
  }

  static Future<Map<String, dynamic>> _post(
      String url, Map<String, String> body) async {
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse(url), body: body)
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw GoogleAuthException('You appear to be offline.');
    } on TimeoutException {
      throw GoogleAuthException('Google took too long to respond.');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = json['error'];
      if (err == 'invalid_grant') {
        throw GoogleAuthException(
            'Google access was revoked or expired — reconnect your Drive.');
      }
      throw GoogleAuthException(
          'Google auth error: ${json['error_description'] ?? err ?? res.statusCode}');
    }
    return json;
  }

  static int _expiry(Map<String, dynamic> tokens) =>
      DateTime.now().millisecondsSinceEpoch +
      ((tokens['expires_in'] as num?)?.toInt() ?? 3600) * 1000;

  static String? _emailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final payload = idToken.split('.')[1];
      final normalized = base64Url.normalize(payload);
      final claims =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      return claims['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String _randomUrlSafe(int bytes) {
    final r = Random.secure();
    return base64Url
        .encode(List.generate(bytes, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }

  static String _landingHtml({required bool ok}) => '''
<!doctype html><html><head><meta charset="utf-8"><title>Quantum Habits</title>
<style>body{background:#0B0E14;color:#E6E9F0;font-family:-apple-system,Segoe UI,sans-serif;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.card{text-align:center;padding:48px;border-radius:24px;background:#141926;
box-shadow:0 8px 40px rgba(0,0,0,.5)}h1{font-weight:600;font-size:22px}
p{color:#8A93A6}</style></head><body><div class="card">
<h1>${ok ? '✅ Drive connected' : '✋ Sign-in not completed'}</h1>
<p>${ok ? 'You can close this tab and return to Quantum Habits.' : 'You can close this tab and try again from the app.'}</p>
</div></body></html>''';
}
