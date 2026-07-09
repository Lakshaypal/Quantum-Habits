import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../challenges/application/challenge_providers.dart';
import '../application/habit_providers.dart';
import '../../focus/focus_timer_screen.dart';
import 'habit_editor_sheet.dart';
import '../data/habit_type.dart';

String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
const _danger = Color(0xFFE5484D);

/// A row in the Today list.
///
/// Interaction is deliberately split so a stray click can't silently complete a
/// habit: the trailing check/＋ button is the ONLY control that logs progress
/// (and it offers UNDO). Tapping the row body — or the ⋯ button — opens the
/// manage menu (reset / archive / delete).
class HabitTile extends ConsumerWidget {
  final Habit habit;
  final HabitEntry? entry;
  const HabitTile({super.key, required this.habit, this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final color = Color(habit.colorValue);
    final type = HabitTypeX.fromIndex(habit.type);
    final done = entry?.completed ?? false;
    final value = entry?.value ?? 0;
    final target = habit.targetValue ?? 1;

    final subtitle = type.needsTarget
        ? '${_fmt(value)} / ${_fmt(target)}${habit.unit != null ? ' ${habit.unit}' : ''}'
        : (habit.category ?? '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _menu(context, ref),
      onLongPress: () => _menu(context, ref),
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.sm, Insets.md),
        decoration: BoxDecoration(
          color: AppColors.graphite.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: done ? color.withValues(alpha: 0.55) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Icon(habitIconData(habit.iconCodePoint), color: color, size: 18),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: t.titleMedium),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle, style: t.bodySmall),
                    ),
                  if (type.needsTarget)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (value / (target == 0 ? 1 : target)).clamp(0, 1).toDouble(),
                          minHeight: 4,
                          backgroundColor: AppColors.graphiteHi,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Manage button (visible, click-friendly on desktop).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _menu(context, ref),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.more_horiz, size: 20, color: AppColors.faint),
              ),
            ),
            const SizedBox(width: 2),
            // Controls that log progress. Counters get −/＋; binary is a toggle.
            if (type == HabitType.binary)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _change(ref, type, add: true),
                child: _Trailing(type: type, done: done, color: color),
              )
            else ...[
              if (value > 0)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _change(ref, type, add: false),
                  child: _circle(Icons.remove, color, filled: false),
                ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _change(ref, type, add: true),
                child: _circle(done ? Icons.check : Icons.add, color, filled: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _change(WidgetRef ref, HabitType type, {required bool add}) async {
    final service = ref.read(habitServiceProvider);
    final now = DateTime.now();
    if (type == HabitType.binary) {
      await service.toggleBinary(habit, now);
    } else if (add) {
      await service.increment(habit, now);
    } else {
      await service.decrement(habit, now);
    }
  }

  Widget _circle(IconData icon, Color color, {required bool filled}) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: Icon(icon, size: 18, color: color),
      );

  void _menu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.graphite,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.xs),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Color(habit.colorValue).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(habitIconData(habit.iconCodePoint),
                        color: Color(habit.colorValue), size: 16),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(child: Text(habit.name, style: Theme.of(sheetCtx).textTheme.titleMedium)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            if (HabitTypeX.fromIndex(habit.type) == HabitType.time)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Start focus session'),
                subtitle: const Text('A timer that logs the minutes for you'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showFocusTimer(context, habit);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit habit'),
              subtitle: const Text('Name, target, color, icon — history stays'),
              onTap: () {
                Navigator.pop(sheetCtx);
                showHabitEditor(context, existing: habit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("Reset today's progress"),
              onTap: () {
                ref.read(habitServiceProvider).reset(habit, DateTime.now());
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive habit'),
              subtitle: const Text('Hide it but keep all history'),
              onTap: () {
                ref.read(habitServiceProvider).archive(habit.id);
                Navigator.pop(sheetCtx);
                _toast(context, '“${habit.name}” archived');
              },
            ),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _danger),
              title: const Text('Delete habit', style: TextStyle(color: _danger)),
              subtitle: const Text('Remove from your habits — past history is kept'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Warn when the habit gates a challenge — deleting it stops it counting
    // toward that challenge from today onward.
    final links = ref.read(challengeHabitsProvider).asData?.value ?? const [];
    final challenges = ref.read(challengesProvider).asData?.value ?? const [];
    final linkedNames = [
      for (final c in challenges)
        if (links.any((l) => l.challengeId == c.id && l.habitId == habit.id))
          c.name
    ];
    final warning = linkedNames.isEmpty
        ? ''
        : '\n\nHeads-up: it’s part of ${linkedNames.map((n) => '“$n”').join(', ')} — '
            'it will stop counting toward ${linkedNames.length == 1 ? 'that challenge' : 'those challenges'}.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.graphiteHi,
        title: Text('Delete “${habit.name}”?'),
        content: Text(
          'It will be removed from your habit list and you’ll stop tracking it. '
          'Its past completions stay in your heatmap and history.$warning',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = ref.read(habitServiceProvider);
    await service.delete(habit.id);
    messenger?.showSnackBar(SnackBar(
      content: Text('“${habit.name}” deleted'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.graphiteHi,
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () => service.restore(habit.id),
      ),
    ));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.graphiteHi,
    ));
  }
}

class _Trailing extends StatelessWidget {
  final HabitType type;
  final bool done;
  final Color color;
  const _Trailing({required this.type, required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    if (type == HabitType.binary) {
      return AnimatedContainer(
        duration: Motion.fast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.transparent,
          border: Border.all(color: done ? color : AppColors.borderStrong, width: 2),
        ),
        child: done ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
      child: Icon(done ? Icons.check : Icons.add, size: 18, color: color),
    );
  }
}
