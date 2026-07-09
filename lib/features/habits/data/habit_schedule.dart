import '../../../core/db/database.dart';

/// How often a habit is meant to be done.
enum ScheduleKind { daily, weekdays, timesPerWeek }

/// A habit's cadence. For [ScheduleKind.weekdays], [mask] is a bitmask over
/// weekdays (bit `weekday-1`, Mon=bit0 … Sun=bit6). For
/// [ScheduleKind.timesPerWeek], [mask] carries the weekly target count.
class HabitSchedule {
  final ScheduleKind kind;
  final int mask;
  const HabitSchedule(this.kind, this.mask);

  static const everyday = HabitSchedule(ScheduleKind.daily, 0);

  factory HabitSchedule.from(int kindIndex, int mask) => HabitSchedule(
        ScheduleKind.values[kindIndex.clamp(0, ScheduleKind.values.length - 1)],
        mask,
      );

  bool weekdaySelected(int weekday) => (mask & (1 << (weekday - 1))) != 0;

  int get timesTarget =>
      kind == ScheduleKind.timesPerWeek ? (mask <= 0 ? 1 : mask) : 0;

  /// Belongs in the Today list / eligible for a reminder on [day].
  bool isDueOn(DateTime day) => switch (kind) {
        ScheduleKind.daily => true,
        ScheduleKind.weekdays => mask == 0 ? true : weekdaySelected(day.weekday),
        ScheduleKind.timesPerWeek => true,
      };

  /// NOT doing it on [day] is a genuine miss (daily + on-mask weekdays only).
  /// Times-per-week habits are scored weekly, never per day, so a quiet day
  /// is never a miss.
  bool countsTowardMissOn(DateTime day) => switch (kind) {
        ScheduleKind.daily => true,
        ScheduleKind.weekdays => mask == 0 ? true : weekdaySelected(day.weekday),
        ScheduleKind.timesPerWeek => false,
      };

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get summary => switch (kind) {
        ScheduleKind.daily => 'Every day',
        ScheduleKind.weekdays => _weekdaySummary(),
        ScheduleKind.timesPerWeek => '$timesTarget× per week',
      };

  String _weekdaySummary() {
    if (mask == 0 || mask == 0x7F) return 'Every day';
    if (mask == 0x1F) return 'Weekdays';
    if (mask == 0x60) return 'Weekends';
    return [
      for (var i = 0; i < 7; i++)
        if (mask & (1 << i) != 0) _dayNames[i]
    ].join(' ');
  }
}

/// Reads a habit's schedule from its stored columns.
HabitSchedule scheduleOf(Habit h) =>
    HabitSchedule.from(h.scheduleKind, h.scheduleMask);
