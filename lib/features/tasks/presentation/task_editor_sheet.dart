import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/day.dart';
import '../../../core/widgets/neo_block.dart';
import '../application/task_providers.dart';

const _prioColors = [
  AppColors.faint,
  AppColors.electricBlue,
  AppColors.warmAmber,
  Color(0xFFE5484D),
];

Future<void> showTaskEditor(BuildContext context, {Task? existing}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => TaskEditorSheet(existing: existing),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  final Task? existing;
  const TaskEditorSheet({super.key, this.existing});
  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _due = widget.existing?.dueDate;
  late int? _dueMinutes = widget.existing?.dueMinutes;
  late int _priority = widget.existing?.priority ?? 1;
  bool _error = false;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final service = ref.read(taskServiceProvider);
      if (_isEdit) {
        await service.update(widget.existing!,
            title: title,
            notes: notes,
            dueDate: _due,
            dueMinutes: _due == null ? null : _dueMinutes,
            priority: _priority);
      } else {
        await service.add(
            title: title,
            notes: notes,
            dueDate: _due,
            dueMinutes: _due == null ? null : _dueMinutes,
            priority: _priority);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save the task: $e')));
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _due = dayKey(picked));
  }

  Future<void> _pickTime() async {
    final initial = _dueMinutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked != null) {
      setState(() => _dueMinutes = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = _prioColors[_priority.clamp(0, 3)];
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
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(_isEdit ? 'Edit task' : 'New task', style: t.headlineSmall),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _title,
              autofocus: !_isEdit,
              style: t.bodyLarge,
              decoration: _dec('What needs doing?',
                  hint: 'Ship the report, call the bank…', error: _error),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              style: t.bodyMedium,
              decoration: _dec('Notes (optional)'),
            ),
            const SizedBox(height: Insets.lg),
            Text('DUE', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                _chip(
                  icon: Icons.event_outlined,
                  label: _due == null
                      ? 'No date'
                      : '${_due!.day}/${_due!.month}/${_due!.year}',
                  selected: _due != null,
                  accent: accent,
                  onTap: _pickDate,
                ),
                if (_due != null)
                  _chip(
                    icon: Icons.schedule_outlined,
                    label: _dueMinutes == null
                        ? 'Add time'
                        : _fmtTime(_dueMinutes!),
                    selected: _dueMinutes != null,
                    accent: accent,
                    onTap: _pickTime,
                  ),
                if (_due != null)
                  _chip(
                    icon: Icons.close,
                    label: 'Clear',
                    selected: false,
                    accent: accent,
                    onTap: () => setState(() {
                      _due = null;
                      _dueMinutes = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Text('PRIORITY', style: t.labelSmall),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                for (var p = 0; p < 4; p++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding:
                              const EdgeInsets.symmetric(vertical: Insets.sm),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _priority == p
                                ? _prioColors[p].withValues(alpha: 0.2)
                                : AppColors.graphiteHi,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                                color: _priority == p
                                    ? _prioColors[p]
                                    : AppColors.border),
                          ),
                          child: Text(kPriorityLabels[p],
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _priority == p
                                      ? AppColors.frostWhite
                                      : AppColors.muted)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            Align(
              alignment: Alignment.centerRight,
              child: NeoBlock(
                color: accent == AppColors.faint ? AppColors.electricBlue : accent,
                foreground: Colors.white,
                onTap: _busy ? null : _save,
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xl, vertical: Insets.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isEdit ? Icons.check : Icons.add, size: 18),
                  const SizedBox(width: Insets.sm),
                  Text(_isEdit ? 'Save changes' : 'Add task'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: Insets.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.electricBlue.withValues(alpha: 0.16)
                : AppColors.graphiteHi,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? AppColors.electricBlue : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 15,
                color: selected ? AppColors.electricBlue : AppColors.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.frostWhite : AppColors.muted)),
          ]),
        ),
      );

  InputDecoration _dec(String label, {String? hint, bool error = false}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.graphiteHi,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.faint),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide:
              BorderSide(color: error ? AppColors.warmAmber : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.electricBlue),
        ),
      );
}

String _fmtTime(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}
