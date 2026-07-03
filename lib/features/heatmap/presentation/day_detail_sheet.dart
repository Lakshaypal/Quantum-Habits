import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/heatmap_palette.dart';
import '../../../core/util/day.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_type.dart';
import '../application/heatmap_providers.dart';

const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'];
const _levelNames = ['No activity', 'Low', 'Moderate', 'High', 'Perfect day'];

String _fullDate(DateTime d) => '${_weekdays[d.weekday]}, ${_months[d.month]} ${d.day}';
String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

Future<void> showDayDetail(BuildContext context, DateTime day, HeatmapPalette palette) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DayDetailSheet(day: day, palette: palette),
  );
}

/// Tapping a heatmap square opens this. Today and yesterday are **editable**
/// (tap to log); older days are **locked** and read-only.
class DayDetailSheet extends ConsumerWidget {
  final DateTime day;
  final HeatmapPalette palette;
  const DayDetailSheet({super.key, required this.day, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = dayKey(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final thisDay = dayKey(day);
    final editable = thisDay == today || thisDay == yesterday;
    final relLabel = thisDay == today ? 'Today' : (thisDay == yesterday ? 'Yesterday' : null);

    final active = ref.watch(activeHabitsProvider).asData?.value ?? const <Habit>[];
    final any = ref.watch(allHabitsAnyProvider).asData?.value ?? const <Habit>[];
    final byId = {for (final h in any) h.id: h};
    final entries = (ref.watch(allEntriesProvider).asData?.value ?? const <HabitEntry>[])
        .where((e) => isSameDay(e.date, day))
        .toList();
    final entryByHabit = {for (final e in entries) e.habitId: e};
    final level = ref.watch(dayStatsProvider)[thisDay]?.level ?? 0;
    final completed = entries.where((e) => e.completed).toList();
    final service = ref.read(habitServiceProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: const BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      padding: EdgeInsets.only(
        left: Insets.xl,
        right: Insets.xl,
        top: Insets.md,
        bottom: Insets.xl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: palette.levelColor(level), borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(child: Text(_fullDate(day), style: t.titleLarge)),
              if (relLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(relLabel.toUpperCase(),
                      style: t.labelSmall?.copyWith(color: AppColors.electricBlue)),
                )
              else
                Text(_levelNames[level].toUpperCase(), style: t.labelSmall),
            ],
          ),
          const SizedBox(height: Insets.lg),
          if (editable) ...[
            Row(children: [
              const Icon(Icons.touch_app_outlined, size: 14, color: AppColors.faint),
              const SizedBox(width: 6),
              Text('Tap to log — editable', style: t.labelSmall),
            ]),
            const SizedBox(height: Insets.md),
            if (active.isEmpty)
              Text('No active habits to log.', style: t.bodyMedium?.copyWith(color: AppColors.muted))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final h in active)
                        _EditRow(
                          habit: h,
                          entry: entryByHabit[h.id],
                          onAdd: () => HabitTypeX.fromIndex(h.type) == HabitType.binary
                              ? service.toggleBinary(h, day)
                              : service.increment(h, day),
                          onRemove: () => HabitTypeX.fromIndex(h.type) == HabitType.binary
                              ? service.toggleBinary(h, day)
                              : service.decrement(h, day),
                          onClear: () => service.reset(h, day),
                        ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            Row(children: [
              const Icon(Icons.lock_outline, size: 14, color: AppColors.faint),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Locked — you can only edit today and yesterday.',
                    style: t.labelSmall),
              ),
            ]),
            const SizedBox(height: Insets.md),
            if (completed.isEmpty)
              Text('No habits completed on this day.',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted))
            else ...[
              Text('COMPLETED', style: t.labelSmall),
              const SizedBox(height: Insets.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final e in completed) _CompletedRow(entry: e, habit: byId[e.habitId]),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final Habit habit;
  final HabitEntry? entry;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onClear;
  const _EditRow({
    required this.habit,
    required this.entry,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(habit.colorValue);
    final type = HabitTypeX.fromIndex(habit.type);
    final done = entry?.completed ?? false;
    final value = entry?.value ?? 0;
    final target = habit.targetValue ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
            child: Icon(habitIconData(habit.iconCodePoint), color: color, size: 16),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name, style: t.bodyLarge),
                if (type.needsTarget)
                  Text('${_fmt(value)} / ${_fmt(target)}${habit.unit != null ? ' ${habit.unit}' : ''}',
                      style: t.bodySmall),
              ],
            ),
          ),
          if (type == HabitType.binary)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd, // toggles
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : Colors.transparent,
                  border: Border.all(color: done ? color : AppColors.borderStrong, width: 2),
                ),
                child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            )
          else ...[
            // Counter stepper: − removes (long-press clears the day), + adds.
            _StepButton(
                icon: Icons.remove,
                color: color,
                enabled: value > 0,
                onTap: onRemove,
                onLongPress: value > 0 ? onClear : null),
            const SizedBox(width: Insets.sm),
            _StepButton(icon: done ? Icons.check : Icons.add, color: color, filled: true, onTap: onAdd),
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: Icon(icon, size: 16, color: enabled ? color : AppColors.faint),
      ),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  final HabitEntry entry;
  final Habit? habit;
  const _CompletedRow({required this.entry, required this.habit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = habit;
    final color = h != null ? Color(h.colorValue) : AppColors.electricBlue;
    final showValue = h != null && HabitTypeX.fromIndex(h.type).needsTarget;
    final deleted = h?.deletedAt != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
            child: Icon(h != null ? habitIconData(h.iconCodePoint) : Icons.check, size: 16, color: color),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(h?.name ?? 'Habit', style: t.bodyLarge, overflow: TextOverflow.ellipsis)),
                if (deleted)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('(deleted)', style: t.labelSmall?.copyWith(color: AppColors.faint)),
                  ),
              ],
            ),
          ),
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: Text('${_fmt(entry.value)}${h.unit != null ? ' ${h.unit}' : ''}', style: t.labelMedium),
            ),
          Icon(Icons.check_circle, size: 18, color: color),
        ],
      ),
    );
  }
}
