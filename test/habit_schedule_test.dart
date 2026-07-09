import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_habits/features/habits/data/habit_schedule.dart';

void main() {
  // 2026-07-06 is a Monday; 2026-07-11 is a Saturday.
  final monday = DateTime(2026, 7, 6);
  final saturday = DateTime(2026, 7, 11);

  group('HabitSchedule', () {
    test('daily is due and counts every day', () {
      const s = HabitSchedule.everyday;
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn(saturday), isTrue);
      expect(s.countsTowardMissOn(saturday), isTrue);
      expect(s.summary, 'Every day');
    });

    test('weekdays: due Mon–Fri only, weekend is not a miss', () {
      const s = HabitSchedule(ScheduleKind.weekdays, 0x1F); // Mon..Fri
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn(saturday), isFalse);
      expect(s.countsTowardMissOn(monday), isTrue);
      expect(s.countsTowardMissOn(saturday), isFalse);
      expect(s.summary, 'Weekdays');
    });

    test('single-day mask reads its label', () {
      const wed = HabitSchedule(ScheduleKind.weekdays, 0x04); // bit 2 = Wed
      expect(wed.summary, 'Wed');
      expect(wed.isDueOn(DateTime(2026, 7, 8)), isTrue); // Wednesday
      expect(wed.isDueOn(monday), isFalse);
    });

    test('times-per-week is always due but never a per-day miss', () {
      const s = HabitSchedule(ScheduleKind.timesPerWeek, 3);
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn(saturday), isTrue);
      expect(s.countsTowardMissOn(monday), isFalse);
      expect(s.timesTarget, 3);
      expect(s.summary, '3× per week');
    });

    test('round-trips through column ints', () {
      const s = HabitSchedule(ScheduleKind.weekdays, 0x2A);
      final back = HabitSchedule.from(s.kind.index, s.mask);
      expect(back.kind, s.kind);
      expect(back.mask, s.mask);
    });
  });
}
