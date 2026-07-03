import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_version.dart';

/// GitHub repo that hosts releases, as `owner/name`. Push this project to
/// GitHub under this name (or change the constant) and tag releases as
/// `vX.Y.Z` — the CI workflow in .github/workflows/release.yml attaches the
/// platform artifacts automatically.
const kUpdateRepo = 'lakshayfeb/quantum-habits';

class UpdateInfo {
  final String version; // e.g. "2.1.0"
  final String notes;
  final String? assetUrl; // direct download for THIS platform
  final String releaseUrl; // release page fallback
  const UpdateInfo(this.version, this.notes, this.assetUrl, this.releaseUrl);
}

sealed class UpdateCheck {
  const UpdateCheck();
}

class UpToDate extends UpdateCheck {
  final String current;
  const UpToDate(this.current);
}

class UpdateAvailable extends UpdateCheck {
  final String current;
  final UpdateInfo update;
  const UpdateAvailable(this.current, this.update);
}

class UpdateCheckFailed extends UpdateCheck {
  final String reason;
  const UpdateCheckFailed(this.reason);
}

final updateServiceProvider = Provider<UpdateService>((_) => UpdateService());

/// In-app updates for a standalone app: checks GitHub Releases, compares
/// semver against the running build, and hands the right platform asset to
/// the OS to download & install. No update server of ours involved.
class UpdateService {
  Future<UpdateCheck> check() async {
    const current = kAppVersion;
    final http.Response res;
    try {
      res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      return const UpdateCheckFailed('You appear to be offline.');
    } on TimeoutException {
      return const UpdateCheckFailed('GitHub took too long to respond.');
    }
    if (res.statusCode == 404) {
      return const UpdateCheckFailed(
          'No releases published yet for $kUpdateRepo.');
    }
    if (res.statusCode != 200) {
      return UpdateCheckFailed('Update check failed (HTTP ${res.statusCode}).');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return const UpdateCheckFailed('Unexpected response from GitHub.');
    }
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) return const UpdateCheckFailed('Release has no version tag.');
    if (!_isNewer(tag, current)) return UpToDate(current);

    final assets = (json['assets'] as List?) ?? const [];
    final wanted = _platformAssetSuffix();
    String? assetUrl;
    for (final a in assets) {
      final name = ((a as Map)['name'] as String? ?? '').toLowerCase();
      if (wanted != null && name.endsWith(wanted)) {
        assetUrl = a['browser_download_url'] as String?;
        break;
      }
    }
    return UpdateAvailable(
      current,
      UpdateInfo(
        tag,
        json['body'] as String? ?? '',
        assetUrl,
        json['html_url'] as String? ?? 'https://github.com/$kUpdateRepo/releases',
      ),
    );
  }

  /// Hands the platform asset (or release page) to the OS. The download lands
  /// in the browser; installing is one click from there — no partial writes
  /// over a running binary.
  Future<bool> download(UpdateInfo info) {
    final url = info.assetUrl ?? info.releaseUrl;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static String? _platformAssetSuffix() {
    if (Platform.isMacOS) return '-macos.zip';
    if (Platform.isWindows) return '-windows.zip';
    if (Platform.isAndroid) return '-android.apk';
    return null;
  }

  /// Semver-ish compare, tolerant of missing parts ("2.1" == "2.1.0").
  static bool _isNewer(String candidate, String current) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final a = parse(candidate), b = parse(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
