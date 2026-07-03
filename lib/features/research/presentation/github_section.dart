import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../../heatmap/presentation/contribution_heatmap.dart';
import '../application/github_providers.dart';

const _ghGreen = Color(0xFF39D353);

/// GitHub connect + (toggleable) live contribution heatmap for the dashboard.
class GithubSection extends ConsumerWidget {
  const GithubSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cfg = ref.watch(githubConfigProvider).asData?.value;
    if (cfg == null) return const SizedBox.shrink();

    if (!cfg.connected) return const _ConnectCard();

    final username = cfg.username!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.code, size: 14, color: _ghGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text('GITHUB · @$username',
                  style: t.labelSmall?.copyWith(letterSpacing: 1.4),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(cfg.show ? 'Shown' : 'Hidden', style: t.labelSmall),
            Switch(
              value: cfg.show,
              activeThumbColor: _ghGreen,
              onChanged: (v) => ref.read(githubSettingsProvider).setShow(v),
            ),
            IconButton(
              tooltip: 'Disconnect',
              icon: const Icon(Icons.link_off, size: 18, color: AppColors.muted),
              onPressed: () => ref.read(githubSettingsProvider).disconnect(),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        if (cfg.show) _GithubHeatmap(username: username),
      ],
    );
  }
}

class _GithubHeatmap extends ConsumerWidget {
  final String username;
  const _GithubHeatmap({required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dataAsync = ref.watch(githubContributionsProvider(username));
    return SizedBox(
      height: 230,
      child: GlassCard(
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _ghGreen)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
                const SizedBox(height: Insets.sm),
                Text('$e'.replaceFirst('Exception: ', ''),
                    style: t.bodySmall, textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(githubContributionsProvider(username)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (gh) => Column(
            children: [
              Row(
                children: [
                  Text('${gh.total}',
                      style: AppType.mono(size: 18, weight: FontWeight.w700, color: AppColors.frostWhite)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('contributions · last year', style: t.bodySmall)),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.muted),
                    onPressed: () => ref.invalidate(githubContributionsProvider(username)),
                  ),
                ],
              ),
              Expanded(
                child: ContributionHeatmap(
                  stats: gh.stats,
                  palette: HeatmapPalette.githubGreen,
                  range: HeatmapRange.year,
                  onDayTap: (_) {},
                ),
              ),
              const SizedBox(height: Insets.sm),
              const HeatmapLegend(palette: HeatmapPalette.githubGreen),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectCard extends ConsumerStatefulWidget {
  const _ConnectCard();
  @override
  ConsumerState<_ConnectCard> createState() => _ConnectCardState();
}

class _ConnectCardState extends ConsumerState<_ConnectCard> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final name = _controller.text.trim().replaceAll('@', '');
    if (name.isEmpty) return;
    setState(() => _busy = true);
    await ref.read(githubSettingsProvider).connect(name);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.code, color: _ghGreen, size: 20),
            const SizedBox(width: Insets.sm),
            Text('Connect GitHub', style: t.titleMedium),
          ]),
          const SizedBox(height: 6),
          Text('Pull your public commit contributions straight from GitHub onto the dashboard.',
              style: t.bodySmall),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: t.bodyLarge,
                  onSubmitted: (_) => _connect(),
                  decoration: InputDecoration(
                    prefixText: '@',
                    hintText: 'username',
                    filled: true,
                    fillColor: AppColors.graphiteHi,
                    hintStyle: const TextStyle(color: AppColors.faint),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      borderSide: const BorderSide(color: _ghGreen),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              NeoBlock(
                color: _ghGreen,
                foreground: Colors.black,
                onTap: _busy ? null : _connect,
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                child: _busy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
