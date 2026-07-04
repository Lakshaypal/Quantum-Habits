import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../challenges/presentation/challenge_editor_sheet.dart';
import '../../challenges/presentation/challenges_screen.dart';
import '../../habits/presentation/habit_editor_sheet.dart';
import '../../home/presentation/home_screen.dart';
import '../../journal/application/journal_providers.dart';
import '../../journal/presentation/journal_editor_sheet.dart';
import '../../journal/presentation/journal_screen.dart';
import '../../research/presentation/research_screen.dart';
import '../../updates/update_prompt.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  static const _tabs = <({IconData icon, String label})>[
    (icon: Icons.grid_view_rounded, label: 'Home'),
    (icon: Icons.flag_rounded, label: 'Challenges'),
    (icon: Icons.menu_book_rounded, label: 'Journal'),
    (icon: Icons.science_outlined, label: 'Research'),
  ];

  void _fab() {
    switch (_index) {
      case 0:
        showHabitEditor(context);
      case 1:
        showChallengeEditor(context);
      case 2:
        showJournalEditor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The journal FAB only makes sense once the vault is unlocked.
    final journalUnlocked = ref.watch(journalSessionProvider) != null;
    // No FAB on Research (set up via the screen) or on a locked Journal.
    final showFab = _index < 2 || (_index == 2 && journalUnlocked);
    const labels = ['Habit', 'Challenge', 'Entry', ''];

    return Scaffold(
      extendBody: true,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _fab,
              icon: const Icon(Icons.add),
              label: Text(labels[_index], style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: _GlassNav(
        index: _index,
        tabs: _tabs,
        onTap: (i) => setState(() => _index = i),
      ),
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const UpdateBanner(),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [HomeScreen(), ChallengesScreen(), JournalScreen(), ResearchScreen()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating frosted-glass pill navigation, centered above the bottom edge.
class _GlassNav extends StatelessWidget {
  final int index;
  final List<({IconData icon, String label})> tabs;
  final ValueChanged<int> onTap;
  const _GlassNav({required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.graphite.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < tabs.length; i++)
                      _NavItem(
                        icon: tabs[i].icon,
                        label: tabs[i].label,
                        selected: i == index,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.electricBlue : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.electricBlue.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (selected) ...[
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
