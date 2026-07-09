import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../habits/data/habit_type.dart';
import '../../heatmap/application/heatmap_providers.dart';
import '../../heatmap/presentation/contribution_heatmap.dart';
import '../../heatmap/presentation/day_detail_sheet.dart';
import '../application/analytics_providers.dart';
import '../application/insights_providers.dart';

HeatmapRange _rangeFor(ReviewPeriod p) => switch (p) {
      ReviewPeriod.week => HeatmapRange.week,
      ReviewPeriod.month => HeatmapRange.month,
      ReviewPeriod.year => HeatmapRange.year,
    };

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  ReviewPeriod _period = ReviewPeriod.week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = ref.watch(analyticsProvider(_period));
    final stats = ref.watch(dayStatsProvider);
    final insights = ref.watch(insightsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Review', style: t.titleLarge),
      ),
      body: AuroraBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
            children: [
              _PeriodSwitcher(period: _period, onChanged: (p) => setState(() => _period = p)),
              const SizedBox(height: Insets.lg),
              _HeroScore(summary: s),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(child: _StatTile('ACTIVE DAYS', '${s.activeDays}', 'of ${s.days}', AppColors.electricBlue)),
                  const SizedBox(width: Insets.md),
                  Expanded(child: _StatTile('PERFECT', '${s.perfectDays}', 'days', AppColors.softPurple)),
                  const SizedBox(width: Insets.md),
                  Expanded(child: _StatTile('JOURNAL', '${s.journalCount}', 'entries', AppColors.warmAmber)),
                ],
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: Insets.lg),
                Text('INSIGHTS', style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: Insets.md),
                for (final ins in insights) ...[
                  _InsightCard(insight: ins),
                  const SizedBox(height: Insets.sm),
                ],
              ],
              const SizedBox(height: Insets.lg),
              Text(_period == ReviewPeriod.year ? 'LIFE CONTRIBUTION GRAPH' : 'HEATMAP REPLAY',
                  style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
              const SizedBox(height: Insets.md),
              SizedBox(
                height: 220,
                child: GlassCard(
                  child: Column(
                    children: [
                      Expanded(
                        child: ContributionHeatmap(
                          stats: stats,
                          palette: HeatmapPalette.frostBlue,
                          range: _rangeFor(_period),
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
              if (s.top.isNotEmpty) ...[
                Text('TOP HABITS', style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: Insets.md),
                GlassCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < s.top.length; i++) ...[
                        if (i > 0) const Divider(height: Insets.lg, color: AppColors.border),
                        _HabitRow(
                          name: s.top[i].habit.name,
                          icon: habitIconData(s.top[i].habit.iconCodePoint),
                          color: Color(s.top[i].habit.colorValue),
                          trailing: '${s.top[i].count}×',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (s.missed.isNotEmpty) ...[
                const SizedBox(height: Insets.lg),
                Text('NEEDS ATTENTION', style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: Insets.md),
                GlassCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < s.missed.length; i++) ...[
                        if (i > 0) const Divider(height: Insets.lg, color: AppColors.border),
                        _HabitRow(
                          name: s.missed[i].name,
                          icon: habitIconData(s.missed[i].iconCodePoint),
                          color: AppColors.faint,
                          trailing: '0×',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  final ReviewPeriod period;
  final ValueChanged<ReviewPeriod> onChanged;
  const _PeriodSwitcher({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.graphite.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final p in ReviewPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == period ? AppColors.electricBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p == period ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroScore extends StatelessWidget {
  final AnalyticsSummary summary;
  const _HeroScore({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONSISTENCY SCORE', style: t.labelSmall),
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${summary.consistencyScore}',
                        style: AppType.mono(size: 44, weight: FontWeight.w700, color: AppColors.frostWhite)),
                    Text(' / 100', style: AppType.mono(size: 14, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${(summary.completionPct * 100).round()}% of all habit-days completed',
                    style: t.bodySmall),
              ],
            ),
          ),
          _Ring(value: summary.completionPct),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double value;
  const _Ring({required this.value});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: AppColors.graphiteHi,
              valueColor: const AlwaysStoppedAnimation(AppColors.electricBlue),
            ),
          ),
          Text('${(value * 100).round()}%',
              style: AppType.mono(size: 13, weight: FontWeight.w700, color: AppColors.frostWhite)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  const _StatTile(this.label, this.value, this.unit, this.accent);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.mono(size: 22, weight: FontWeight.w700, color: AppColors.frostWhite)),
              const SizedBox(width: 3),
              Flexible(child: Text(unit, style: AppType.mono(size: 10, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: t.labelSmall, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = switch (insight.tone) {
      InsightTone.positive => const Color(0xFF34D399),
      InsightTone.warn => AppColors.warmAmber,
      InsightTone.neutral => AppColors.electricBlue,
    };
    return GlassCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(insight.icon, color: color, size: 16),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(insight.text,
                style: t.bodyMedium?.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final String trailing;
  const _HabitRow({required this.name, required this.icon, required this.color, required this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(trailing, style: AppType.mono(size: 13, weight: FontWeight.w600, color: AppColors.muted)),
      ],
    );
  }
}
