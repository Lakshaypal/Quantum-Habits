import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/neo_block.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/data/habit_type.dart';
import '../application/challenge_providers.dart';
import '../data/challenge_model.dart';
import '../../../core/util/day.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${_mon[d.month]} ${d.day}, ${d.year}';

/// Pass [existing] (with its current [links]) to edit a running challenge —
/// progress is preserved; only the rules, look and roster change.
Future<void> showChallengeEditor(BuildContext context,
    {Challenge? existing, List<ChallengeHabit> links = const []}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ChallengeEditorSheet(existing: existing, links: links),
  );
}

// 0 excluded · 1 mandatory · 2 flexible
class ChallengeEditorSheet extends ConsumerStatefulWidget {
  final Challenge? existing;
  final List<ChallengeHabit> links;
  const ChallengeEditorSheet({super.key, this.existing, this.links = const []});
  @override
  ConsumerState<ChallengeEditorSheet> createState() => _ChallengeEditorSheetState();
}

class _ChallengeEditorSheetState extends ConsumerState<ChallengeEditorSheet> {
  final _name = TextEditingController();
  int _days = 30;
  ChallengeMode _mode = ChallengeMode.flexible;
  int _allowedMisses = 3;
  Color _color = AppColors.electricBlue;
  IconData _icon = Icons.flag_rounded;
  final Map<String, int> _habitState = {};
  bool _error = false;
  String? _habitError;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c == null) return;
    _name.text = c.name;
    _days = daysBetween(dayKey(c.startDate), dayKey(c.endDate)) + 1;
    _mode = ChallengeModeX.fromIndex(c.mode);
    _allowedMisses = c.allowedMisses;
    _color = Color(c.colorValue);
    if (c.iconCodePoint != null) _icon = habitIconData(c.iconCodePoint!);
    for (final l in widget.links) {
      _habitState[l.habitId] = l.mandatory ? 1 : 2;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _applyTemplate(ChallengeTemplate t) {
    setState(() {
      _name.text = t.name;
      _days = t.days;
      _mode = t.mode;
      _allowedMisses = t.allowedMisses;
      _color = t.color;
      _icon = t.icon;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = true);
      return;
    }
    final habits = <({String habitId, bool mandatory})>[];
    _habitState.forEach((id, state) {
      if (state == 1) habits.add((habitId: id, mandatory: true));
      if (state == 2) habits.add((habitId: id, mandatory: false));
    });
    // A challenge with no habits has nothing to score — every day would
    // count as a miss.
    if (habits.isEmpty) {
      setState(() =>
          _habitError = 'Attach at least one habit — it’s what gets scored.');
      return;
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(challengeServiceProvider);
      if (_isEdit) {
        final c = widget.existing!;
        await service.update(
          c,
          name: name,
          description: c.description,
          start: c.startDate,
          end: addDays(dayKey(c.startDate), _days - 1),
          mode: _mode,
          allowedMisses: _mode == ChallengeMode.flexible ? _allowedMisses : 0,
          color: _color,
          icon: _icon,
          habits: habits,
          currentLinks: widget.links,
        );
      } else {
        final start = DateTime.now();
        await service.create(
          name: name,
          start: start,
          end: addDays(dayKey(start), _days - 1),
          mode: _mode,
          allowedMisses: _mode == ChallengeMode.flexible ? _allowedMisses : 0,
          color: _color,
          icon: _icon,
          habits: habits,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save the challenge: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final habits = ref.watch(activeHabitsProvider).asData?.value ?? const <Habit>[];
    final start = DateTime.now();
    final end = addDays(dayKey(start), _days - 1);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
            Text(_isEdit ? 'Edit challenge' : 'New challenge',
                style: t.headlineSmall),
            const SizedBox(height: Insets.lg),
            Text('TEMPLATES', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kChallengeTemplates.length,
                separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
                itemBuilder: (_, i) {
                  final tpl = kChallengeTemplates[i];
                  return GestureDetector(
                    onTap: () => _applyTemplate(tpl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                      decoration: BoxDecoration(
                        color: tpl.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(color: tpl.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(tpl.icon, size: 15, color: tpl.color),
                          const SizedBox(width: 6),
                          Text(tpl.name,
                              style: TextStyle(
                                  color: tpl.color, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _name,
              style: t.bodyLarge,
              decoration: _dec('Challenge name', hint: '75 Hard, Deep Work Sprint…', error: _error),
            ),
            const SizedBox(height: Insets.lg),
            Text('DURATION', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final d in kDurationPresets)
                  _Pill(
                    label: '$d days',
                    selected: _days == d,
                    accent: _color,
                    onTap: () => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
                _isEdit
                    ? 'Started ${_fmtDate(dayKey(widget.existing!.startDate))} · ends ${_fmtDate(end)}'
                    : 'Starts today · ends ${_fmtDate(end)}',
                style: t.bodySmall),
            const SizedBox(height: Insets.lg),
            Text('MODE', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                for (final m in ChallengeMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: _Pill(
                      label: m.label,
                      selected: _mode == m,
                      accent: _color,
                      onTap: () => setState(() => _mode = m),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_mode.blurb, style: t.bodySmall),
            if (_mode == ChallengeMode.flexible) ...[
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Text('Allowed misses', style: t.bodyMedium),
                  const Spacer(),
                  _StepperButton(icon: Icons.remove, onTap: () => setState(() => _allowedMisses = (_allowedMisses - 1).clamp(0, 99))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                    child: Text('$_allowedMisses', style: t.titleMedium),
                  ),
                  _StepperButton(icon: Icons.add, onTap: () => setState(() => _allowedMisses = (_allowedMisses + 1).clamp(0, 99))),
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
                for (final c in AppColors.habitSwatches)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? AppColors.frostWhite : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Text('HABITS', style: t.labelSmall),
            const SizedBox(height: 2),
            Text('Tap to cycle: off → required → optional', style: t.bodySmall),
            const SizedBox(height: Insets.sm),
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.md),
                child: Text('No habits yet. Add a habit first, then attach it to a challenge.',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              )
            else
              ...habits.map((h) => _HabitPicker(
                    habit: h,
                    state: _habitState[h.id] ?? 0,
                    onTap: () => setState(() {
                      _habitState[h.id] = ((_habitState[h.id] ?? 0) + 1) % 3;
                      _habitError = null;
                    }),
                  )),
            if (_habitError != null) ...[
              const SizedBox(height: Insets.sm),
              Text(_habitError!,
                  style: t.bodySmall?.copyWith(color: AppColors.warmAmber)),
            ],
            const SizedBox(height: Insets.xl),
            Align(
              alignment: Alignment.centerRight,
              child: NeoBlock(
                color: _color,
                onTap: _busy ? null : _save,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isEdit ? Icons.check : Icons.flag_rounded, size: 18),
                  const SizedBox(width: Insets.sm),
                  Text(_isEdit ? 'Save changes' : 'Start challenge'),
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

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : AppColors.graphiteHi,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.frostWhite : AppColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5)),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.graphiteHi,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.frostWhite),
      ),
    );
  }
}

class _HabitPicker extends StatelessWidget {
  final Habit habit;
  final int state; // 0 off, 1 mandatory, 2 flexible
  final VoidCallback onTap;
  const _HabitPicker({required this.habit, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(habit.colorValue);
    final (label, chipColor) = switch (state) {
      1 => ('Required', AppColors.electricBlue),
      2 => ('Optional', AppColors.softPurple),
      _ => ('Off', AppColors.faint),
    };
    final on = state != 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.graphiteHi,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: on ? chipColor.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(habitIconData(habit.iconCodePoint), size: 18, color: color),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(habit.name, style: t.titleMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: on ? 0.18 : 0.0),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chipColor.withValues(alpha: on ? 0.5 : 0.3)),
              ),
              child: Text(label,
                  style: TextStyle(color: chipColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
