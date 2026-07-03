import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/util/day.dart';
import '../../heatmap/application/heatmap_providers.dart';

class GithubContributions {
  final String username;
  final int total;
  final Map<DateTime, DayStat> stats; // level already 0–4 from GitHub
  const GithubContributions(this.username, this.total, this.stats);
}

/// Pulls a user's public contribution calendar straight from GitHub, via a
/// no-auth community proxy that returns the same daily counts + levels GitHub
/// shows on a profile. No token required.
class GithubService {
  Future<GithubContributions> fetch(String username) async {
    final u = username.trim().replaceAll('@', '');
    if (u.isEmpty) throw Exception('Enter a GitHub username.');
    final uri = Uri.parse('https://github-contributions-api.jogruber.de/v4/$u?y=last');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) throw Exception('GitHub user “$u” not found.');
    if (res.statusCode != 200) throw Exception('GitHub request failed (${res.statusCode}).');

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['contributions'] as List?) ?? const [];
    final stats = <DateTime, DayStat>{};
    var total = 0;
    for (final raw in list) {
      final c = raw as Map<String, dynamic>;
      final date = dayKey(DateTime.parse(c['date'] as String));
      final count = (c['count'] as num?)?.toInt() ?? 0;
      final level = (c['level'] as num?)?.toInt() ?? 0;
      total += count;
      stats[date] = DayStat(date, count, 0, level);
    }
    return GithubContributions(u, total, stats);
  }
}
