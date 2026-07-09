import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/util/current_day.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/neo_block.dart';
import '../habits/application/habit_providers.dart';

/// A focus (Pomodoro) session for a time-based habit. When the session ends —
/// or the user finishes early — the elapsed whole minutes are logged to the
/// habit for today. Time is measured against the wall clock, so leaving the
/// app and coming back never loses (or invents) minutes.
Future<void> showFocusTimer(BuildContext context, Habit habit) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => FocusTimerScreen(habit: habit)),
  );
}

class FocusTimerScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const FocusTimerScreen({super.key, required this.habit});
  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen> {
  late int _sessionMinutes;
  Duration _accumulated = Duration.zero;
  DateTime? _resumedAt;
  Timer? _ticker;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final target = widget.habit.targetValue;
    _sessionMinutes = (target != null && target > 0) ? target.round() : 25;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _running => _resumedAt != null;

  Duration get _elapsed =>
      _accumulated + (_running ? DateTime.now().difference(_resumedAt!) : Duration.zero);

  Duration get _remaining {
    final total = Duration(minutes: _sessionMinutes);
    final left = total - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _start() {
    setState(() => _resumedAt = DateTime.now());
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_elapsed >= Duration(minutes: _sessionMinutes)) {
        _finish(auto: true);
      } else {
        setState(() {});
      }
    });
  }

  void _pause() {
    setState(() {
      _accumulated = _elapsed;
      _resumedAt = null;
    });
    _ticker?.cancel();
  }

  void _adjust(int delta) {
    setState(() => _sessionMinutes = (_sessionMinutes + delta).clamp(5, 180));
  }

  Future<void> _finish({bool auto = false}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final elapsed = auto ? Duration(minutes: _sessionMinutes) : _elapsed;
    final minutes = (elapsed.inSeconds / 60).round();
    final today = ref.read(currentDayProvider);
    if (minutes >= 1) {
      await ref
          .read(habitServiceProvider)
          .increment(widget.habit, today, by: minutes.toDouble());
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(minutes >= 1
          ? 'Logged $minutes min to ${widget.habit.name}.'
          : 'No time logged.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.graphiteHi,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(widget.habit.colorValue);
    final total = Duration(minutes: _sessionMinutes);
    final progress = total.inSeconds == 0
        ? 0.0
        : (_elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final started = _accumulated > Duration.zero || _running;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.habit.name, style: t.titleLarge),
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: AppColors.graphiteHi,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmt(_remaining),
                              style: AppType.mono(
                                  size: 52,
                                  weight: FontWeight.w700,
                                  color: AppColors.frostWhite)),
                          Text(_running ? 'focusing' : (started ? 'paused' : 'ready'),
                              style: t.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.xl),
                if (!started)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _round(Icons.remove, () => _adjust(-5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                        child: Text('$_sessionMinutes min', style: t.titleMedium),
                      ),
                      _round(Icons.add, () => _adjust(5)),
                    ],
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: NeoBlock(
                        color: color,
                        foreground: Colors.white,
                        onTap: _running ? _pause : _start,
                        padding: const EdgeInsets.symmetric(vertical: Insets.md),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_running ? Icons.pause : Icons.play_arrow, size: 20),
                              const SizedBox(width: Insets.sm),
                              Text(_running ? 'Pause' : (started ? 'Resume' : 'Start')),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (started) ...[
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _finish(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: Insets.md),
                            decoration: BoxDecoration(
                              color: AppColors.graphiteHi,
                              borderRadius: BorderRadius.circular(Radii.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: Text('Log & finish',
                                  style: t.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.graphiteHi,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.frostWhite),
        ),
      );

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
