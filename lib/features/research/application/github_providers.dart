import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/application/habit_providers.dart' show databaseProvider;
import 'github_service.dart';

final githubServiceProvider = Provider<GithubService>((ref) => GithubService());

class GithubConfig {
  final String? username; // null when not connected
  final bool show; // whether to render on the dashboard
  const GithubConfig(this.username, this.show);
  bool get connected => username != null && username!.isNotEmpty;
}

/// Persisted GitHub connection (username + show-on-dashboard toggle).
final githubConfigProvider = FutureProvider<GithubConfig>((ref) async {
  final db = ref.watch(databaseProvider);
  final u = await db.getKV('github_username');
  final show = await db.getKV('github_show');
  return GithubConfig((u == null || u.isEmpty) ? null : u, show != '0');
});

/// Live fetch of a username's contributions (cached per username).
final githubContributionsProvider =
    FutureProvider.family<GithubContributions, String>((ref, username) {
  return ref.watch(githubServiceProvider).fetch(username);
});

final githubSettingsProvider = Provider<GithubSettings>((ref) => GithubSettings(ref));

class GithubSettings {
  final Ref _ref;
  GithubSettings(this._ref);

  Future<void> connect(String username, {bool show = true}) async {
    final db = _ref.read(databaseProvider);
    await db.setKV('github_username', username.trim().replaceAll('@', ''));
    await db.setKV('github_show', show ? '1' : '0');
    _ref.invalidate(githubConfigProvider);
  }

  Future<void> setShow(bool show) async {
    await _ref.read(databaseProvider).setKV('github_show', show ? '1' : '0');
    _ref.invalidate(githubConfigProvider);
  }

  Future<void> disconnect() async {
    await _ref.read(databaseProvider).setKV('github_username', '');
    _ref.invalidate(githubConfigProvider);
  }
}
