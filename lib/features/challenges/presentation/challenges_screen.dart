import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../habits/data/habit_type.dart';
import '../application/challenge_providers.dart';
import '../data/challenge_model.dart';
import 'challenge_detail_screen.dart';
import 'challenge_editor_sheet.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final challenges = ref.watch(challengesProvider).asData?.value ?? const <Challenge>[];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: Insets.lg),
              Text('Challenges', style: t.displaySmall),
              const SizedBox(height: 2),
              Text('Commit to a sprint. Consistency beats intensity.', style: t.bodySmall),
              const SizedBox(height: Insets.lg),
              if (challenges.isEmpty)
                _EmptyChallenges(onAdd: () => showChallengeEditor(context))
              else
                ...challenges.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: ChallengeCard(challenge: c),
                    )),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }
}

({String label, Color color}) challengeStatus(ChallengeProgress p) {
  if (p.startsInFuture) return (label: 'Upcoming', color: AppColors.muted);
  if (p.complete) return (label: 'Completed', color: AppColors.electricBlue);
  if (p.failed) return (label: p.strict ? 'Streak broken' : 'Over limit', color: AppColors.warmAmber);
  return (label: 'Active', color: AppColors.softPurple);
}

class ChallengeCard extends ConsumerWidget {
  final Challenge challenge;
  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = ref.watch(challengeProgressProvider(challenge));
    final color = Color(challenge.colorValue);
    final status = challengeStatus(p);
    final icon = challenge.iconCodePoint != null
        ? habitIconData(challenge.iconCodePoint!)
        : Icons.flag_rounded;

    return GlassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challenge: challenge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.name, style: t.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Day ${p.elapsedDays} of ${p.totalDays} · ${ChallengeModeX.fromIndex(challenge.mode).label}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
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
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Text('${(p.percent * 100).round()}%',
                  style: AppType.mono(size: 15, weight: FontWeight.w700, color: AppColors.frostWhite)),
              const SizedBox(width: Insets.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: p.percent.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: AppColors.graphiteHi,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              for (int i = 0; i < 4; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.milestones[i] ? color : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyChallenges({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(vertical: Insets.xl, horizontal: Insets.lg),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.muted, size: 26),
          const SizedBox(height: Insets.md),
          Text('Start your first challenge', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('75 Hard, 100 Days of Code, or your own.',
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
