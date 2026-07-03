import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/widgets/glass_card.dart';
import '../../analytics/presentation/analytics_screen.dart';
import '../../sync/presentation/sync_settings_screen.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/presentation/habit_editor_sheet.dart';
import '../../habits/presentation/habit_tile.dart';
import '../../heatmap/application/heatmap_providers.dart';
import '../../heatmap/presentation/contribution_heatmap.dart';
import '../../heatmap/presentation/day_detail_sheet.dart';
import '../../quotes/quotes.dart';

const _weekdays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HeatmapRange _range = HeatmapRange.year;
  final HeatmapPalette _palette = HeatmapPalette.frostBlue;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dayStatsProvider);
    final habits = ref.watch(activeHabitsProvider).asData?.value ?? const [];
    final todayEntries = ref.watch(todayEntriesProvider).asData?.value ?? const [];
    final entryByHabit = {for (final e in todayEntries) e.habitId: e};
    final streak = ref.watch(streakStatsProvider);
    final quote = ref.watch(quoteOfTheDayProvider);

    final heatmapHeight = (MediaQuery.of(context).size.height * 0.40).clamp(230.0, 440.0);

    return CustomScrollView(
      slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: Insets.lg),
                    _Greeting(streak: streak),
                    const SizedBox(height: Insets.lg),
                    _QuoteCard(quote: quote),
                    const SizedBox(height: Insets.sm),
                    _ConsistencyHeader(
                      range: _range,
                      onChanged: (r) => setState(() => _range = r),
                    ),
                    const SizedBox(height: Insets.md),
                    SizedBox(
                      height: heatmapHeight.toDouble(),
                      child: GlassCard(
                        child: Column(
                          children: [
                            Expanded(
                              child: ContributionHeatmap(
                                stats: stats,
                                palette: _palette,
                                range: _range,
                                onDayTap: (d) => showDayDetail(context, d, _palette),
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            HeatmapLegend(palette: _palette),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    _StatsRow(streak: streak),
                    const SizedBox(height: Insets.sm),
                    _SectionLabel(habits.isEmpty ? 'Today' : 'Today · ${habits.length}'),
                    if (habits.isEmpty)
                      _EmptyToday(onAdd: () => showHabitEditor(context))
                    else
                      ...habits.map((h) => HabitTile(habit: h, entry: entryByHabit[h.id])),
                    const SizedBox(height: 96),
                  ]),
                ),
              ),
            ],
        );
  }
}

class _Greeting extends StatelessWidget {
  final StreakStats streak;
  const _Greeting({required this.streak});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final date = '${_weekdays[now.weekday]}, ${_months[now.month]} ${now.day}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: t.displaySmall),
              const SizedBox(height: 2),
              Text(date, style: t.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cloud Sync',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SyncSettingsScreen())),
          icon: const Icon(Icons.cloud_outlined),
          color: AppColors.muted,
        ),
        IconButton(
          tooltip: 'Review & insights',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          icon: const Icon(Icons.insights_rounded),
          color: AppColors.muted,
        ),
        if (streak.current > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.warmAmber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('${streak.current} day${streak.current == 1 ? '' : 's'}',
                    style: AppType.mono(size: 12, weight: FontWeight.w600, color: AppColors.warmAmber)),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${quote.text}”',
              style: t.titleMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w500)),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Text(quote.author.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: AppColors.frostWhite, letterSpacing: 1.2)),
              const SizedBox(width: Insets.sm),
              Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.faint, shape: BoxShape.circle)),
              const SizedBox(width: Insets.sm),
              Text(quote.field.toUpperCase(), style: t.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsistencyHeader extends StatelessWidget {
  final HeatmapRange range;
  final ValueChanged<HeatmapRange> onChanged;
  const _ConsistencyHeader({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.xs),
      child: Row(
        children: [
          Expanded(child: Text('CONSISTENCY', style: t.labelSmall?.copyWith(letterSpacing: 1.6))),
          _RangeSwitcher(range: range, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RangeSwitcher extends StatelessWidget {
  final HeatmapRange range;
  final ValueChanged<HeatmapRange> onChanged;
  const _RangeSwitcher({required this.range, required this.onChanged});

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
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in HeatmapRange.values)
            GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: r == range ? AppColors.electricBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: r == range ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final StreakStats streak;
  const _StatsRow({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(label: 'CURRENT', value: '${streak.current}', unit: 'days', accent: AppColors.warmAmber)),
        const SizedBox(width: Insets.md),
        Expanded(child: _StatTile(label: 'LONGEST', value: '${streak.longest}', unit: 'days', accent: AppColors.softPurple)),
        const SizedBox(width: Insets.md),
        Expanded(
            child: _StatTile(
                label: '30-DAY',
                value: '${(streak.monthlyConsistency * 100).round()}',
                unit: '%',
                accent: AppColors.electricBlue)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  const _StatTile({required this.label, required this.value, required this.unit, required this.accent});

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
              Text(value, style: AppType.mono(size: 24, weight: FontWeight.w700, color: AppColors.frostWhite)),
              const SizedBox(width: 3),
              Text(unit, style: AppType.mono(size: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: t.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.md),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.6)),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyToday({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(vertical: Insets.xl, horizontal: Insets.lg),
      child: Column(
        children: [
          const Icon(Icons.add_circle_outline, color: AppColors.muted, size: 26),
          const SizedBox(height: Insets.md),
          Text('Add your first habit', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Small actions, compounded daily.',
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
