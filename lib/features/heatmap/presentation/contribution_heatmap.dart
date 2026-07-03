import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/util/day.dart';
import '../application/heatmap_providers.dart';

enum HeatmapRange { week, month, quarter, year }

extension HeatmapRangeX on HeatmapRange {
  String get label => switch (this) {
        HeatmapRange.week => 'Week',
        HeatmapRange.month => 'Month',
        HeatmapRange.quarter => 'Quarter',
        HeatmapRange.year => 'Year',
      };
  int get days => switch (this) {
        HeatmapRange.week => 7,
        HeatmapRange.month => 34,
        HeatmapRange.quarter => 97,
        HeatmapRange.year => 364,
      };
}

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _levelNames = ['No activity', 'Low', 'Moderate', 'High', 'Perfect day'];
String _tip(DateTime d, int level) => '${_months[d.month]} ${d.day} · ${_levelNames[level]}';

/// GitHub-style contribution graph — the hero element. Weeks are columns,
/// weekdays are rows; cell color encodes daily completion level 0–4.
class ContributionHeatmap extends StatelessWidget {
  final Map<DateTime, DayStat> stats;
  final HeatmapPalette palette;
  final HeatmapRange range;
  final void Function(DateTime day) onDayTap;

  const ContributionHeatmap({
    super.key,
    required this.stats,
    required this.palette,
    required this.range,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = dayKey(DateTime.now());
    final firstWeek = startOfWeek(today.subtract(Duration(days: range.days)));
    final lastWeek = startOfWeek(today);
    final weekCount = lastWeek.difference(firstWeek).inDays ~/ 7 + 1;

    return LayoutBuilder(builder: (context, c) {
      const gap = 3.0;
      const labelH = 14.0;
      final gridMaxH = c.maxHeight - labelH - Insets.sm;
      final maxCell = weekCount <= 2 ? 40.0 : (weekCount <= 6 ? 30.0 : 26.0);
      double cell = ((gridMaxH - 6 * gap) / 7).clamp(10.0, maxCell);

      bool scroll = false;
      if (weekCount * (cell + gap) > c.maxWidth + 0.5) {
        final fit = ((c.maxWidth - (weekCount - 1) * gap) / weekCount).clamp(0.0, cell);
        if (fit >= 9.0) {
          cell = fit;
        } else {
          cell = 9.0;
          scroll = true;
        }
      }
      final radius = (cell * 0.28).clamp(2.0, 6.0);

      final content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthLabels(firstWeek: firstWeek, weekCount: weekCount, cell: cell, gap: gap),
          const SizedBox(height: Insets.sm),
          _Grid(
            firstWeek: firstWeek,
            weekCount: weekCount,
            today: today,
            cell: cell,
            gap: gap,
            radius: radius,
            stats: stats,
            palette: palette,
            onDayTap: onDayTap,
          ),
        ],
      );

      if (scroll) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: content,
        );
      }
      return Align(alignment: Alignment.centerLeft, child: content);
    });
  }
}

class _Grid extends StatelessWidget {
  final DateTime firstWeek;
  final int weekCount;
  final DateTime today;
  final double cell;
  final double gap;
  final double radius;
  final Map<DateTime, DayStat> stats;
  final HeatmapPalette palette;
  final void Function(DateTime day) onDayTap;

  const _Grid({
    required this.firstWeek,
    required this.weekCount,
    required this.today,
    required this.cell,
    required this.gap,
    required this.radius,
    required this.stats,
    required this.palette,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[];
    for (int w = 0; w < weekCount; w++) {
      final cells = <Widget>[];
      for (int d = 0; d < 7; d++) {
        final date = firstWeek.add(Duration(days: w * 7 + d));
        final future = date.isAfter(today);
        final level = stats[date]?.level ?? 0;
        cells.add(Padding(
          padding: EdgeInsets.only(bottom: d < 6 ? gap : 0),
          child: _Cell(
            date: date,
            level: level,
            future: future,
            size: cell,
            radius: radius,
            palette: palette,
            onTap: () => onDayTap(date),
          ),
        ));
      }
      columns.add(Padding(
        padding: EdgeInsets.only(right: w < weekCount - 1 ? gap : 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: cells),
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: columns);
  }
}

class _Cell extends StatelessWidget {
  final DateTime date;
  final int level;
  final bool future;
  final double size;
  final double radius;
  final HeatmapPalette palette;
  final VoidCallback onTap;

  const _Cell({
    required this.date,
    required this.level,
    required this.future,
    required this.size,
    required this.radius,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = future ? AppColors.border : palette.levelColor(level);
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: future ? 0.25 : 1),
        borderRadius: BorderRadius.circular(radius),
        border: (!future && level == 0)
            ? Border.all(color: AppColors.border, width: 0.5)
            : null,
      ),
    );
    if (future) return cell;
    return Tooltip(
      message: _tip(date, level),
      waitDuration: const Duration(milliseconds: 350),
      child: GestureDetector(onTap: onTap, child: cell),
    );
  }
}

class _MonthLabels extends StatelessWidget {
  final DateTime firstWeek;
  final int weekCount;
  final double cell;
  final double gap;

  const _MonthLabels({
    required this.firstWeek,
    required this.weekCount,
    required this.cell,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9.5, letterSpacing: 0.5);
    final children = <Widget>[];
    int? lastMonth;
    for (int w = 0; w < weekCount; w++) {
      final weekStart = firstWeek.add(Duration(days: w * 7));
      String text = '';
      if (weekStart.month != lastMonth) {
        text = _months[weekStart.month];
        lastMonth = weekStart.month;
      }
      children.add(SizedBox(
        width: cell + (w < weekCount - 1 ? gap : 0),
        child: text.isEmpty
            ? null
            : Text(text, style: style, softWrap: false, overflow: TextOverflow.visible),
      ));
    }
    return SizedBox(height: 14, child: Row(children: children));
  }
}

/// "Less ▢▢▢▢▢ More" legend for the heatmap.
class HeatmapLegend extends StatelessWidget {
  final HeatmapPalette palette;
  const HeatmapLegend({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: t),
        const SizedBox(width: Insets.sm),
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: palette.levelColor(i),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: Insets.sm),
        Text('More', style: t),
      ],
    );
  }
}
