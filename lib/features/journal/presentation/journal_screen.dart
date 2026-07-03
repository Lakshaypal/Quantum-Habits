import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../application/journal_providers.dart';
import '../data/journal_kind.dart';
import 'burn_ritual.dart';
import 'journal_editor_sheet.dart';
import 'journal_lock_view.dart';

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Journal tab: shows the lock gate until unlocked, then the entry list.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(journalSessionProvider);
    if (vault == null) return const JournalLockView();
    return const _JournalList();
  }
}

class _JournalList extends ConsumerWidget {
  const _JournalList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final entriesAsync = ref.watch(decryptedJournalProvider);
    final isSunday = DateTime.now().weekday == DateTime.sunday;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: Insets.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Journal', style: t.displaySmall),
                        Row(children: [
                          const Icon(Icons.lock_outline, size: 12, color: AppColors.faint),
                          const SizedBox(width: 4),
                          Text('Encrypted · on this device', style: t.bodySmall),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sunday Burn',
                    onPressed: () => showBurnRitual(context),
                    icon: const Icon(Icons.local_fire_department_outlined),
                    color: AppColors.warmAmber,
                  ),
                  IconButton(
                    tooltip: 'Lock journal',
                    onPressed: () => ref.read(journalSessionProvider.notifier).lock(),
                    icon: const Icon(Icons.lock_open_outlined),
                    color: AppColors.muted,
                  ),
                ],
              ),
              if (isSunday) ...[
                const SizedBox(height: Insets.md),
                _SundayBanner(onTap: () => showBurnRitual(context)),
              ],
              const SizedBox(height: Insets.md),
              entriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: Insets.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Could not read entries: $e', style: t.bodyMedium),
                data: (entries) => entries.isEmpty
                    ? _EmptyJournal(onAdd: () => showJournalEditor(context))
                    : Column(
                        children: [
                          for (final e in entries)
                            _EntryCard(entry: e, onTap: () => showJournalEditor(context, existing: e)),
                        ],
                      ),
              ),
              const SizedBox(height: 96),
            ]),
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final DecryptedEntry entry;
  final VoidCallback onTap;
  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kind = entry.kind;
    final created = entry.meta.createdAt;
    final preview = entry.body.trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final title = entry.title.trim().isEmpty ? kind.label : entry.title.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Icon(kind.icon, color: kind.color, size: 18),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${_months[created.month]} ${created.day}', style: t.labelSmall),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(preview, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SundayBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SundayBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      tint: AppColors.warmAmber.withValues(alpha: 0.10),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_outlined, color: AppColors.warmAmber),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sunday ritual', style: t.titleMedium),
                Text('What are you ready to let go of?', style: t.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyJournal({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(vertical: Insets.xl, horizontal: Insets.lg),
      child: Column(
        children: [
          const Icon(Icons.edit_note, color: AppColors.muted, size: 26),
          const SizedBox(height: Insets.md),
          Text('Write your first entry', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Private, encrypted, yours alone.', style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
