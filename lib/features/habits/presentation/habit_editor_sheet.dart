import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/neo_block.dart';
import '../application/habit_providers.dart';
import '../data/habit_type.dart';

/// Pass [existing] to edit a habit in place — same identity, entries and
/// heatmap history; only its look and rules change.
Future<void> showHabitEditor(BuildContext context, {Habit? existing}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => HabitEditorSheet(existing: existing),
  );
}

class HabitEditorSheet extends ConsumerStatefulWidget {
  final Habit? existing;
  const HabitEditorSheet({super.key, this.existing});
  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _target = TextEditingController();
  final _unit = TextEditingController();
  HabitType _type = HabitType.binary;
  int _colorIndex = 0;
  int _iconIndex = 0;
  bool _error = false;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h == null) return;
    _name.text = h.name;
    _category.text = h.category ?? '';
    if (h.targetValue != null) {
      _target.text = h.targetValue!.truncateToDouble() == h.targetValue!
          ? h.targetValue!.toInt().toString()
          : h.targetValue!.toString();
    }
    _unit.text = h.unit ?? '';
    _type = HabitType.values[h.type.clamp(0, HabitType.values.length - 1)];
    final colorIdx = AppColors.habitSwatches
        .indexWhere((c) => c.toARGB32() == h.colorValue);
    if (colorIdx >= 0) _colorIndex = colorIdx;
    final iconIdx =
        kHabitIcons.indexWhere((i) => i.codePoint == h.iconCodePoint);
    if (iconIdx >= 0) _iconIndex = iconIdx;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(habitServiceProvider);
      final category =
          _category.text.trim().isEmpty ? null : _category.text.trim();
      final target =
          _type.needsTarget ? double.tryParse(_target.text.trim()) : null;
      final unit = _type.needsTarget && _unit.text.trim().isNotEmpty
          ? _unit.text.trim()
          : null;
      if (_isEdit) {
        await service.updateHabit(
          widget.existing!,
          name: name,
          type: _type,
          color: AppColors.habitSwatches[_colorIndex],
          icon: kHabitIcons[_iconIndex],
          category: category,
          target: target,
          unit: unit,
        );
      } else {
        await service.addHabit(
          name: name,
          type: _type,
          color: AppColors.habitSwatches[_colorIndex],
          icon: kHabitIcons[_iconIndex],
          category: category,
          target: target,
          unit: unit,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save the habit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = AppColors.habitSwatches[_colorIndex];
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
            Text(_isEdit ? 'Edit habit' : 'New habit', style: t.headlineSmall),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _name,
              autofocus: true,
              style: t.bodyLarge,
              decoration: _dec('Name', hint: 'Deep Work, Reading, Workout…', error: _error),
            ),
            const SizedBox(height: Insets.lg),
            Text('TYPE', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final type in HabitType.values)
                  _Choice(
                    label: type.label,
                    icon: type.typeIcon,
                    selected: _type == type,
                    accent: accent,
                    onTap: () => setState(() => _type = type),
                  ),
              ],
            ),
            if (_type.needsTarget) ...[
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: t.bodyLarge,
                      decoration: _dec('Target', hint: _type == HabitType.time ? '30' : '5'),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      style: t.bodyLarge,
                      decoration: _dec('Unit', hint: _type == HabitType.time ? 'min' : 'reps'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Insets.lg),
            Text('COLOR', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.md,
              runSpacing: Insets.md,
              children: [
                for (int i = 0; i < AppColors.habitSwatches.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.habitSwatches[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIndex == i ? AppColors.frostWhite : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Text('ICON', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (int i = 0; i < kHabitIcons.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _iconIndex = i),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iconIndex == i ? accent.withValues(alpha: 0.2) : AppColors.graphiteHi,
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(
                          color: _iconIndex == i ? accent : AppColors.border,
                        ),
                      ),
                      child: Icon(kHabitIcons[i],
                          size: 20, color: _iconIndex == i ? accent : AppColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _category,
              style: t.bodyLarge,
              decoration: _dec('Category (optional)', hint: 'Fitness, Research, Mind…'),
            ),
            const SizedBox(height: Insets.xl),
            Align(
              alignment: Alignment.centerRight,
              child: NeoBlock(
                color: accent,
                onTap: _busy ? null : _save,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isEdit ? Icons.check : Icons.add, size: 18),
                  const SizedBox(width: Insets.sm),
                  Text(_isEdit ? 'Save changes' : 'Create habit'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint, bool error = false}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.graphiteHi,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: error ? AppColors.warmAmber : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.electricBlue),
        ),
      );
}

class _Choice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : AppColors.graphiteHi,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: selected ? accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? accent : AppColors.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.frostWhite : AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
