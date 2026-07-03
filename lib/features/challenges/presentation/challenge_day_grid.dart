import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/challenge_providers.dart';

/// The challenge's heatmap overlay: one cell per day in the window, colored by
/// pass / miss / pending / future.
class ChallengeDayGrid extends StatelessWidget {
  final Map<DateTime, int> dayStatus;
  final DateTime start;
  final int totalDays;
  final Color color;
  const ChallengeDayGrid({
    super.key,
    required this.dayStatus,
    required this.start,
    required this.totalDays,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (int i = 0; i < totalDays; i++) _cell(start.add(Duration(days: i))),
      ],
    );
  }

  Widget _cell(DateTime d) {
    final s = dayStatus[d] ?? dayFuture;
    Color c;
    Border? border;
    switch (s) {
      case dayPass:
        c = color;
      case dayMiss:
        c = const Color(0xFF34232B);
        border = Border.all(color: const Color(0x40FF6B6B));
      case dayPending:
        c = color.withValues(alpha: 0.25);
        border = Border.all(color: color, width: 1.2);
      default:
        c = AppColors.border;
    }
    return Tooltip(
      message: 'Day ${d.difference(start).inDays + 1}',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4), border: border),
      ),
    );
  }
}
