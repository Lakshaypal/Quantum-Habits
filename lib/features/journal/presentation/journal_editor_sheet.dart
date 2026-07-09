import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/neo_block.dart';
import '../application/journal_providers.dart';
import '../data/journal_kind.dart';
import '../data/journal_mood.dart';

Future<void> showJournalEditor(BuildContext context,
    {DecryptedEntry? existing, String? promptText}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => JournalEditorSheet(existing: existing, promptText: promptText),
  );
}

class JournalEditorSheet extends ConsumerStatefulWidget {
  final DecryptedEntry? existing;
  final String? promptText;
  const JournalEditorSheet({super.key, this.existing, this.promptText});
  @override
  ConsumerState<JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends ConsumerState<JournalEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.existing?.body ?? '');
  late JournalKind _kind = widget.existing?.kind ?? JournalKind.daily;
  late Mood? _mood = widget.existing?.mood;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vault = ref.read(journalSessionProvider);
    if (vault == null) {
      Navigator.of(context).pop();
      return;
    }
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    await ref.read(journalServiceProvider).save(
          id: widget.existing?.meta.id,
          kind: _kind,
          title: _title.text.trim(),
          body: _body.text,
          vault: vault,
          createdAt: widget.existing?.meta.createdAt,
          mood: _mood,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
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
      child: SingleChildScrollView(
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
                const Icon(Icons.lock_outline, size: 14, color: AppColors.faint),
                const SizedBox(width: 6),
                Text('ENCRYPTED', style: t.labelSmall),
              ],
            ),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final k in JournalKind.values)
                  _KindChip(kind: k, selected: _kind == k, onTap: () => setState(() => _kind = k)),
              ],
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _title,
              style: t.titleLarge,
              decoration: InputDecoration(
                hintText: 'Title (optional)',
                hintStyle: t.titleLarge?.copyWith(color: AppColors.faint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const Divider(height: Insets.lg, color: AppColors.border),
            TextField(
              controller: _body,
              autofocus: true,
              minLines: 6,
              maxLines: 14,
              style: t.bodyLarge?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: widget.promptText ?? _kind.prompt,
                hintStyle: t.bodyLarge?.copyWith(color: AppColors.faint),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('HOW ARE YOU FEELING?', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                for (final m in Mood.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _mood = _mood == m ? null : m),
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                          decoration: BoxDecoration(
                            color: _mood == m
                                ? m.color.withValues(alpha: 0.2)
                                : AppColors.graphiteHi,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                                color: _mood == m ? m.color : AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Text(m.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 2),
                              Text(m.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _mood == m
                                          ? AppColors.frostWhite
                                          : AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Align(
              alignment: Alignment.centerRight,
              child: NeoBlock(
                color: _kind.color,
                foreground: Colors.white,
                onTap: _busy ? null : _save,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                child: Text(widget.existing == null ? 'Save entry' : 'Update entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final JournalKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        decoration: BoxDecoration(
          color: selected ? kind.color.withValues(alpha: 0.2) : AppColors.graphiteHi,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: selected ? kind.color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kind.icon, size: 15, color: selected ? kind.color : AppColors.muted),
            const SizedBox(width: 6),
            Text(kind.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.frostWhite : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
