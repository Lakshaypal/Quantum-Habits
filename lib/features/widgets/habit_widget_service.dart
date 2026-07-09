import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/heatmap_palette.dart';
import '../../core/util/day.dart';
import '../heatmap/application/heatmap_providers.dart';

/// Pushes a rendered heatmap + streak into the Android home-screen widget.
/// The heatmap is drawn in Flutter and handed to the widget as a PNG, so the
/// native side stays a trivial ImageView (see HabitWidgetProvider.kt).
class HabitWidgetService {
  static const _androidName = 'HabitWidgetProvider';
  static const _weeks = 18; // ~4 months of history at a glance

  static Future<void> update({
    required Map<DateTime, DayStat> stats,
    required HeatmapPalette palette,
    required int currentStreak,
    required DateTime today,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.saveWidgetData<String>('streak', '$currentStreak');
      await HomeWidget.renderFlutterWidget(
        _WidgetHeatmap(stats: stats, palette: palette, today: today),
        key: 'heatmap',
        logicalSize: const Size(340, 132),
        pixelRatio: 2.5,
      );
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (_) {/* widget is best-effort; never crash the app */}
  }
}

/// A self-contained, theme-independent heatmap for off-screen rendering —
/// no MediaQuery/Theme lookups, all colors explicit.
class _WidgetHeatmap extends StatelessWidget {
  final Map<DateTime, DayStat> stats;
  final HeatmapPalette palette;
  final DateTime today;
  const _WidgetHeatmap(
      {required this.stats, required this.palette, required this.today});

  @override
  Widget build(BuildContext context) {
    const cell = 12.0, gap = 3.0;
    final firstWeek = startOfWeek(addDays(today, -(HabitWidgetService._weeks - 1) * 7));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 340,
        height: 132,
        padding: const EdgeInsets.all(14),
        color: const Color(0xFF0A0B0D),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quantum Habits',
                style: TextStyle(
                    color: Color(0xFFF4F6FB),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var w = 0; w < HabitWidgetService._weeks; w++)
                  Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: () {
                              final date = addDays(firstWeek, w * 7 + d);
                              final level = date.isAfter(today)
                                  ? -1
                                  : (stats[date]?.level ?? 0);
                              return Container(
                                width: cell,
                                height: cell,
                                decoration: BoxDecoration(
                                  color: level < 0
                                      ? Colors.transparent
                                      : palette.levelColor(level),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
