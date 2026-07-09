import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _bundleId = 'com.quantumhabits.quantumHabits';

/// One-time move of the database out of the old macOS App Sandbox container.
///
/// v2.2.0 drops the sandbox (so the in-app updater can replace its own
/// bundle). Dropping the sandbox changes where `getApplicationSupportDirectory`
/// points — from `~/Library/Containers/<id>/Data/Library/Application Support`
/// to `~/Library/Application Support`. Without this copy, an existing user's
/// data would look empty until Drive re-synced it; with it, nothing blinks.
///
/// Runs before the database is opened. Best-effort: any failure is swallowed,
/// and Google Drive sync remains the ultimate backstop.
Future<void> migrateMacSandboxDataIfNeeded() async {
  if (!Platform.isMacOS) return;
  try {
    final dir = await getApplicationSupportDirectory();
    final newPath = dir.path;
    const marker = '/Library/Application Support';
    // Already in (or still in) the container → nothing to do.
    if (newPath.contains('/Library/Containers/') ||
        !newPath.contains(marker)) {
      return;
    }
    if (_hasSqlite(dir)) return; // already populated

    final suffix = newPath.substring(newPath.indexOf(marker) + marker.length);
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final oldDir = Directory(
        '$home/Library/Containers/$_bundleId/Data/Library/Application Support$suffix');
    if (!oldDir.existsSync() || !_hasSqlite(oldDir)) return;

    dir.createSync(recursive: true);
    for (final entity in oldDir.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        entity.copySync('${dir.path}/$name');
      }
    }
  } catch (_) {/* Drive sync will restore it anyway */}
}

bool _hasSqlite(Directory dir) {
  if (!dir.existsSync()) return false;
  return dir
      .listSync()
      .whereType<File>()
      .any((f) => f.path.endsWith('.sqlite'));
}
