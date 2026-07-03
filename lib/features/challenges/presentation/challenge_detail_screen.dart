import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/util/day.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_type.dart';
import '../application/challenge_providers.dart';
import 'certificate_view.dart';
import 'challenge_day_grid.dart';
import 'challenges_screen.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  final Challenge challenge;
  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final color = Color(challenge.colorValue);
    final p = ref.watch(challengeProgressProvider(challenge));
    final status = challengeStatus(p);

    final links = (ref.watch(challengeHabitsProvider).asData?.value ?? const <ChallengeHabit>[])
        .where((l) => l.challengeId == challenge.id)
        .toList();
    final byId = {for (final h in ref.watch(activeHabitsProvider).asData?.value ?? const <Habit>[]) h.id: h};
    final entryByHabit = {
      for (final e in ref.watch(todayEntriesProvider).asData?.value ?? const <HabitEntry>[]) e.habitId: e
    };

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TopBar(name: challenge.name, color: color, challengeId: challenge.id),
                    const SizedBox(height: Insets.md),
                    _HeaderCard(challenge: challenge, progress: p, color: color, status: status),
                    const SizedBox(height: Insets.lg),
                    Text('MILESTONES', style: t.labelSmall),
                    const SizedBox(height: Insets.md),
                    _MilestoneTimeline(percent: p.percent, color: color),
                    const SizedBox(height: Insets.xl),
                    Text('PROGRESS MAP', style: t.labelSmall),
                    const SizedBox(height: Insets.md),
                    GlassCard(
                      child: ChallengeDayGrid(
                        dayStatus: p.dayStatus,
                        start: dayKey(challenge.startDate),
                        totalDays: p.totalDays,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    Text('HABITS', style: t.labelSmall),
                    const SizedBox(height: Insets.md),
                    if (links.isEmpty)
                      Text('No habits attached to this challenge.',
                          style: t.bodyMedium?.copyWith(color: AppColors.muted))
                    else
                      ...links.map((l) {
                        final h = byId[l.habitId];
                        if (h == null) return const SizedBox.shrink();
                        return _ChallengeHabitRow(
                          habit: h,
                          mandatory: l.mandatory,
                          entry: entryByHabit[h.id],
                        );
                      }),
                    if (p.complete) ...[
                      const SizedBox(height: Insets.xl),
                      Center(
                        child: NeoBlock(
                          color: color,
                          padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => CertificateView(challenge: challenge, progress: p)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.workspace_premium_outlined, size: 18),
                            SizedBox(width: Insets.sm),
                            Text('View certificate'),
                          ]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String name;
  final Color color;
  final String challengeId;
  const _TopBar({required this.name, required this.color, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(name, style: t.headlineSmall, overflow: TextOverflow.ellipsis)),
          PopupMenuButton<String>(
            color: AppColors.graphiteHi,
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (v) async {
              final service = ref.read(challengeServiceProvider);
              if (v == 'archive') await service.archive(challengeId);
              if (v == 'delete') await service.remove(challengeId);
              if (context.mounted) Navigator.of(context).pop();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Archive')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Challenge challenge;
  final ChallengeProgress progress;
  final Color color;
  final ({String label, Color color}) status;
  const _HeaderCard({
    required this.challenge,
    required this.progress,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progress;
    final detail = p.strict
        ? 'Streak ${p.currentStreak} · strict'
        : 'Misses ${p.missedDays}/${p.allowedMisses}';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: status.color.withValues(alpha: 0.4)),
                ),
                child: Text(status.label,
                    style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 11.5)),
              ),
              const Spacer(),
              Text('Day ${p.elapsedDays} of ${p.totalDays}', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${(p.percent * 100).round()}',
                  style: AppType.mono(size: 42, weight: FontWeight.w700, color: AppColors.frostWhite)),
              Text('%', style: AppType.mono(size: 18, color: AppColors.muted)),
              const Spacer(),
              Text(detail, style: t.labelMedium),
            ],
          ),
          const SizedBox(height: Insets.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p.percent.clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.graphiteHi,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (p.failed && !p.complete) ...[
            const SizedBox(height: Insets.md),
            Text(
              p.strict
                  ? 'A day was missed — strict mode resets the streak. Keep going; every day still counts.'
                  : 'You\'ve used more than the allowed misses. The map below shows where.',
              style: t.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneTimeline extends StatelessWidget {
  final double percent;
  final Color color;
  const _MilestoneTimeline({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const marks = [0.25, 0.5, 0.75, 1.0];
    return Row(
      children: [
        for (int i = 0; i < marks.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (percent >= marks[i - 1] ? color : AppColors.border),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: percent >= marks[i] ? color : AppColors.graphiteHi,
                        border: Border.all(
                          color: percent >= marks[i] ? color : AppColors.border,
                        ),
                      ),
                      child: percent >= marks[i]
                          ? const Icon(Icons.check, size: 14, color: Colors.black)
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == marks.length - 1 ? Colors.transparent : (percent >= marks[i] ? color : AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${(marks[i] * 100).round()}%',
                    style: t.labelSmall?.copyWith(
                        color: percent >= marks[i] ? AppColors.frostWhite : AppColors.faint)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChallengeHabitRow extends ConsumerWidget {
  final Habit habit;
  final bool mandatory;
  final HabitEntry? entry;
  const _ChallengeHabitRow({required this.habit, required this.mandatory, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final color = Color(habit.colorValue);
    final type = HabitTypeX.fromIndex(habit.type);
    final done = entry?.completed ?? false;

    void act() {
      final s = ref.read(habitServiceProvider);
      if (type == HabitType.binary) {
        s.toggleBinary(habit, DateTime.now());
      } else {
        s.increment(habit, DateTime.now());
      }
    }

    return GestureDetector(
      onTap: act,
      child: Container(
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.graphite.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: done ? color.withValues(alpha: 0.55) : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(habitIconData(habit.iconCodePoint), color: color, size: 18),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(habit.name, style: t.titleMedium)),
            Text(mandatory ? 'Required' : 'Optional',
                style: t.labelSmall?.copyWith(
                    color: mandatory ? AppColors.electricBlue : AppColors.softPurple)),
            const SizedBox(width: Insets.md),
            AnimatedContainer(
              duration: Motion.fast,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : Colors.transparent,
                border: Border.all(color: done ? color : AppColors.borderStrong, width: 2),
              ),
              child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
