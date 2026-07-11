import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/current_day.dart';
import '../../../core/util/day.dart';
import '../../../core/widgets/glass_card.dart';
import '../application/task_providers.dart';
import 'task_editor_sheet.dart';

const _prioColors = [
  AppColors.faint,
  AppColors.electricBlue,
  AppColors.warmAmber,
  Color(0xFFE5484D),
];
const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final buckets = ref.watch(taskBucketsProvider);
    final today = ref.watch(currentDayProvider);
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 96;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: Insets.lg),
              Text('Tasks', style: t.displaySmall),
              const SizedBox(height: 2),
              Text(
                buckets.openCount == 0
                    ? 'A clear plate. Add what matters next.'
                    : '${buckets.openCount} open · one honest list, no piles.',
                style: t.bodySmall,
              ),
              const SizedBox(height: Insets.lg),
              if (buckets.openCount == 0 && buckets.done.isEmpty)
                _EmptyTasks(onAdd: () => showTaskEditor(context)),
              ..._section(context, 'OVERDUE', buckets.overdue, today,
                  tone: const Color(0xFFE5484D)),
              ..._section(context, 'TODAY', buckets.today, today),
              ..._section(context, 'UPCOMING', buckets.upcoming, today),
              ..._section(context, 'SOMEDAY', buckets.someday, today),
              if (buckets.done.isNotEmpty) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showDone = !_showDone),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                    child: Row(children: [
                      Text('DONE · ${buckets.done.length}',
                          style: t.labelSmall?.copyWith(letterSpacing: 1.6)),
                      const SizedBox(width: Insets.sm),
                      Icon(_showDone ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: AppColors.faint),
                    ]),
                  ),
                ),
                if (_showDone)
                  for (final task in buckets.done)
                    _TaskRow(task: task, today: today, muted: true),
              ],
              SizedBox(height: bottomClearance),
            ]),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
      BuildContext context, String label, List<Task> tasks, DateTime today,
      {Color? tone}) {
    if (tasks.isEmpty) return const [];
    final t = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.only(top: Insets.md, bottom: Insets.sm),
        child: Text(label,
            style: t.labelSmall
                ?.copyWith(letterSpacing: 1.6, color: tone ?? AppColors.muted)),
      ),
      for (final task in tasks) _TaskRow(task: task, today: today),
    ];
  }
}

class _TaskRow extends ConsumerWidget {
  final Task task;
  final DateTime today;
  final bool muted;
  const _TaskRow({required this.task, required this.today, this.muted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final prio = _prioColors[task.priority.clamp(0, 3)];
    final due = task.dueDate;
    String? dueLabel;
    Color dueColor = AppColors.muted;
    if (due != null) {
      final d = dayKey(due);
      final diff = daysBetween(today, d);
      if (diff < 0) {
        dueLabel = diff == -1 ? 'yesterday' : '${-diff} days ago';
        dueColor = const Color(0xFFE5484D);
      } else if (diff == 0) {
        dueLabel = task.dueMinutes == null ? 'today' : _fmtTime(task.dueMinutes!);
        dueColor = AppColors.warmAmber;
      } else if (diff == 1) {
        dueLabel = 'tomorrow';
      } else if (diff < 7) {
        dueLabel = 'in $diff days';
      } else {
        dueLabel = '${_months[d.month]} ${d.day}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: GlassCard(
        onTap: () => showTaskEditor(context, existing: task),
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.sm),
        child: Row(
          children: [
            // The one control that flips done — separate from row tap (edit).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final service = ref.read(taskServiceProvider);
                await service.setDone(task.id, !task.done);
                if (!task.done && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('“${task.title}” done'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.graphiteHi,
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () => service.setDone(task.id, false),
                    ),
                  ));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.done ? prio : Colors.transparent,
                    border: Border.all(
                        color: task.done ? prio : AppColors.borderStrong,
                        width: 2),
                  ),
                  child: task.done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      color: muted || task.done ? AppColors.muted : null,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.faint,
                    ),
                  ),
                  if ((task.notes ?? '').isNotEmpty)
                    Text(task.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall),
                ],
              ),
            ),
            if (task.priority >= 2 && !task.done)
              Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: Icon(Icons.flag, size: 14, color: prio),
              ),
            if (dueLabel != null && !task.done)
              Text(dueLabel, style: t.labelSmall?.copyWith(color: dueColor)),
            PopupMenuButton<String>(
              color: AppColors.graphiteHi,
              icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.faint),
              onSelected: (v) async {
                final service = ref.read(taskServiceProvider);
                if (v == 'edit') {
                  await showTaskEditor(context, existing: task);
                } else if (v == 'delete') {
                  await service.remove(task.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('“${task.title}” deleted'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.graphiteHi,
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () => service.restore(task),
                      ),
                    ));
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTasks({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onAdd,
      padding:
          const EdgeInsets.symmetric(vertical: Insets.xl, horizontal: Insets.lg),
      child: Column(
        children: [
          const Icon(Icons.playlist_add_check_circle_outlined,
              color: AppColors.muted, size: 26),
          const SizedBox(height: Insets.md),
          Text('Add your first task', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Due dates, priorities and reminders — synced everywhere.',
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String _fmtTime(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}
