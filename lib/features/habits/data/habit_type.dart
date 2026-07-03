import 'package:flutter/material.dart';

/// The four habit measurement models from the spec.
enum HabitType { binary, count, time, goal }

extension HabitTypeX on HabitType {
  static HabitType fromIndex(int i) => HabitType.values[i.clamp(0, HabitType.values.length - 1)];

  String get label => switch (this) {
        HabitType.binary => 'Yes / No',
        HabitType.count => 'Count',
        HabitType.time => 'Time',
        HabitType.goal => 'Goal',
      };

  String get hint => switch (this) {
        HabitType.binary => 'Done or not done',
        HabitType.count => 'Track repetitions',
        HabitType.time => 'Track minutes',
        HabitType.goal => 'Reach a target value',
      };

  IconData get typeIcon => switch (this) {
        HabitType.binary => Icons.check_circle_outline,
        HabitType.count => Icons.add_circle_outline,
        HabitType.time => Icons.timer_outlined,
        HabitType.goal => Icons.flag_outlined,
      };

  bool get needsTarget => this != HabitType.binary;
}

/// Habit icons are persisted as code points, so the [IconData] is necessarily
/// dynamic. Release builds must pass `--no-tree-shake-icons`.
IconData habitIconData(int codePoint) =>
    // ignore: non_const_argument_for_const_parameter
    IconData(codePoint, fontFamily: 'MaterialIcons');

/// Curated icon set offered in the habit editor (Workout, Reading, …).
const kHabitIcons = <IconData>[
  Icons.fitness_center,
  Icons.menu_book,
  Icons.self_improvement,
  Icons.code,
  Icons.science,
  Icons.edit_note,
  Icons.directions_walk,
  Icons.bolt,
  Icons.water_drop,
  Icons.bedtime,
  Icons.psychology,
  Icons.language,
];
