import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/data/habit_type.dart';
import '../../heatmap/presentation/contribution_heatmap.dart';
import '../../heatmap/presentation/day_detail_sheet.dart';
import '../application/research_providers.dart';
import 'github_section.dart';

({String value, String unit}) _format(MetricTotal m) {
  if (m.habit.unit == 'min') {
    final hrs = m.total / 60;
    return (value: hrs.toStringAsFixed(hrs >= 10 ? 0 : 1), unit: 'hrs');
  }
  final binary = HabitTypeX.fromIndex(m.habit.type) == HabitType.binary;
  return (value: m.total.toStringAsFixed(0), unit: m.habit.unit ?? (binary ? 'days' : ''));
}

String _week(MetricTotal m) {
  if (m.week <= 0) return 'none this week';
  if (m.habit.unit == 'min') return '+${(m.week / 60).toStringAsFixed(1)}h this week';
  return '+${m.week.toStringAsFixed(0)} this week';
}

class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final habits = ref.watch(researchHabitsProvider);
    final metrics = ref.watch(researchMetricsProvider);
    final stats = ref.watch(researchDayStatsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: Insets.lg),
              Text("Researcher's Dashboard", style: t.displaySmall),
              const SizedBox(height: 2),
              Text('Papers, deep work, code, experiments — on one graph.', style: t.bodySmall),
              const SizedBox(height: Insets.lg),
              if (habits.isEmpty)
                _SetupCard(onSetup: () => ref.read(researchSetupProvider)())
              else ...[
                SizedBox(
                  height: 240,
                  child: GlassCard(
                    child: Column(
                      children: [
                        Expanded(
                          child: ContributionHeatmap(
                            stats: stats,
                            palette: HeatmapPalette.frostBlue,
                            range: HeatmapRange.year,
                            onDayTap: (d) => showDayDetail(context, d, HeatmapPalette.frostBlue),
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        const HeatmapLegend(palette: HeatmapPalette.frostBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Text('METRICS', style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: Insets.md),
                LayoutBuilder(builder: (context, c) {
                  const gap = Insets.md;
                  final w = (c.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final m in metrics) SizedBox(width: w, child: _MetricCard(metric: m)),
                    ],
                  );
                }),
                const SizedBox(height: Insets.lg),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: AppColors.faint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Log these from Today on the Home tab — they feed this graph live.',
                          style: t.bodySmall),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Insets.lg),
              const GithubSection(),
              const SizedBox(height: 96),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final MetricTotal metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(metric.habit.colorValue);
    final f = _format(metric);
    return GlassCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
                child: Icon(habitIconData(metric.habit.iconCodePoint), color: color, size: 16),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(metric.habit.name,
                    style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(f.value, style: AppType.mono(size: 26, weight: FontWeight.w700, color: AppColors.frostWhite)),
              const SizedBox(width: 4),
              Text(f.unit, style: AppType.mono(size: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(_week(metric), style: t.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final VoidCallback onSetup;
  const _SetupCard({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF22D3EE), size: 28),
          const SizedBox(height: Insets.md),
          Text('Set up Researcher Mode', style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Adds six metrics — Papers Read, Deep Work, Coding, Experiments, '
            'GitHub Commits, and Gym — that track on the same heatmap as the rest '
            'of your system. Tune or remove any of them later.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: Insets.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: NeoBlock(
              color: const Color(0xFF22D3EE),
              foreground: Colors.black,
              onTap: onSetup,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: Insets.sm),
                Text('Set up metrics'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
