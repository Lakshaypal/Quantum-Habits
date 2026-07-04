import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_version.dart';
import '../../core/db/database.dart';

/// Public, binaries-only repo that hosts releases (the source code lives in
/// a separate private repo). Tag the private repo `vX.Y.Z` — its CI builds
/// the artifacts and publishes the release here, and every installed copy
/// self-updates from it.
const kUpdateRepo = 'Lakshaypal/quantum-habits-releases';

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

/// Set when a launch-time check finds a newer release; RootShell shows the
/// update banner while this is non-null.
final pendingUpdateProvider =
    NotifierProvider<PendingUpdate, UpdateAvailable?>(PendingUpdate.new);

class PendingUpdate extends Notifier<UpdateAvailable?> {
  @override
  UpdateAvailable? build() => null;
  void set(UpdateAvailable? value) => state = value;
}

final updateServiceProvider = Provider<UpdateService>((_) => UpdateService());

/// Self-updates for a standalone app: checks GitHub Releases on launch,
/// prompts in-app, downloads the platform asset and installs it —
/// no store, no website hunt.
///
/// Install mechanics per platform:
///  - macOS/Windows: download + unpack to temp, then a detached script swaps
///    the app while it's closed and relaunches it.
///  - Android: download the APK and hand it to the system installer
///    (REQUEST_INSTALL_PACKAGES + FileProvider; the OS shows "Update app?").
class UpdateService {
  static const _channel = MethodChannel('qh/updates');

  /// Launch-time check, throttled to twice a day so startups stay instant
  /// and offline launches never block.
  Future<UpdateAvailable?> autoCheck(AppDatabase db) async {
    final last = int.tryParse(await db.getKV('last_update_check') ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < 12 * 3600 * 1000) return null;
    await db.setKV('last_update_check', '$now');
    final result = await check();
    return result is UpdateAvailable ? result : null;
  }

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

  /// Downloads and installs [info]. On macOS/Windows this exits the app and
  /// relaunches the new version; on Android the system installer takes over.
  /// Falls back to opening the release page if anything platform-specific
  /// goes wrong.
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final url = info.assetUrl;
    if (url == null) {
      await launchUrl(Uri.parse(info.releaseUrl),
          mode: LaunchMode.externalApplication);
      return;
    }
    try {
      final bytes = await _download(url, onProgress);
      if (Platform.isAndroid) {
        await _installAndroid(bytes);
      } else if (Platform.isMacOS) {
        await _installMacOS(bytes);
      } else if (Platform.isWindows) {
        await _installWindows(bytes);
      } else {
        await launchUrl(Uri.parse(info.releaseUrl),
            mode: LaunchMode.externalApplication);
      }
    } on Exception {
      // Never leave the user stranded — the release page always works.
      await launchUrl(Uri.parse(info.releaseUrl),
          mode: LaunchMode.externalApplication);
      rethrow;
    }
  }

  Future<List<int>> _download(
      String url, void Function(double)? onProgress) async {
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw Exception('Download failed (HTTP ${res.statusCode}).');
      }
      final total = res.contentLength ?? 0;
      final bytes = <int>[];
      await for (final chunk in res.stream.timeout(const Duration(minutes: 5))) {
        bytes.addAll(chunk);
        if (total > 0) onProgress?.call(bytes.length / total);
      }
      return bytes;
    } finally {
      client.close();
    }
  }

  Future<void> _installAndroid(List<int> bytes) async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/updates');
    await dir.create(recursive: true);
    final apk = File('${dir.path}/QuantumHabits-update.apk');
    await apk.writeAsBytes(bytes, flush: true);
    await _channel.invokeMethod('installApk', {'path': apk.path});
    // The system installer UI takes it from here.
  }

  Future<void> _installMacOS(List<int> bytes) async {
    final tmp = await Directory.systemTemp.createTemp('qh_update');
    final zip = File('${tmp.path}/update.zip');
    await zip.writeAsBytes(bytes, flush: true);
    final unpacked = Directory('${tmp.path}/unpacked');
    final res =
        await Process.run('ditto', ['-x', '-k', zip.path, unpacked.path]);
    if (res.exitCode != 0) throw Exception('Could not unpack the update.');
    final newApp = unpacked
        .listSync()
        .whereType<Directory>()
        .firstWhere((d) => d.path.endsWith('.app'),
            orElse: () => throw Exception('Update did not contain an app.'));
    // .../Quantum Habits.app/Contents/MacOS/quantum_habits → the bundle root
    final bundle = File(Platform.resolvedExecutable).parent.parent.parent.path;
    if (!bundle.endsWith('.app')) {
      throw Exception('Not running from an app bundle.');
    }
    final script = File('${tmp.path}/install.sh');
    await script.writeAsString('''#!/bin/bash
sleep 1.5
rm -rf "$bundle"
ditto "${newApp.path}" "$bundle"
open "$bundle"
''');
    await Process.run('chmod', ['+x', script.path]);
    await Process.start('/bin/bash', [script.path],
        mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _installWindows(List<int> bytes) async {
    final tmp = await Directory.systemTemp.createTemp('qh_update');
    final zip = File('${tmp.path}\\update.zip');
    await zip.writeAsBytes(bytes, flush: true);
    final unpacked = '${tmp.path}\\unpacked';
    final res = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Path "${zip.path}" -DestinationPath "$unpacked" -Force',
    ]);
    if (res.exitCode != 0) throw Exception('Could not unpack the update.');
    final installDir = File(Platform.resolvedExecutable).parent.path;
    final exeName = Platform.resolvedExecutable.split('\\').last;
    // A running exe can't be overwritten, but it CAN be renamed.
    final bat = File('${tmp.path}\\install.bat');
    await bat.writeAsString('''@echo off
timeout /t 2 /nobreak >nul
move /y "$installDir\\$exeName" "$installDir\\$exeName.old" >nul
xcopy /e /y /q "$unpacked\\*" "$installDir\\" >nul
start "" "$installDir\\$exeName"
''');
    await Process.start('cmd', ['/c', bat.path],
        mode: ProcessStartMode.detached);
    exit(0);
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
