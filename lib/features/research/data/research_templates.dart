import 'package:flutter/material.dart';

import '../../habits/data/habit_type.dart';

/// Habits in this category are surfaced on the Researcher's Dashboard.
const kResearchCategory = 'Research';

/// One preset metric for the technical-builder workflow.
class ResearchTemplate {
  final String name;
  final HabitType type;
  final IconData icon;
  final Color color;
  final double? target;
  final String? unit;
  const ResearchTemplate(this.name, this.type, this.icon, this.color, {this.target, this.unit});
}

const kResearchTemplates = <ResearchTemplate>[
  ResearchTemplate('Papers Read', HabitType.count, Icons.article_outlined, Color(0xFF22D3EE),
      target: 1, unit: 'papers'),
  ResearchTemplate('Deep Work', HabitType.time, Icons.bolt, Color(0xFF3B82F6),
      target: 120, unit: 'min'),
  ResearchTemplate('Coding', HabitType.time, Icons.code, Color(0xFF8B7CF6), target: 120, unit: 'min'),
  ResearchTemplate('Experiments', HabitType.count, Icons.science_outlined, Color(0xFF34D399),
      target: 1, unit: 'runs'),
  ResearchTemplate('GitHub Commits', HabitType.count, Icons.commit, Color(0xFFF4A340),
      target: 1, unit: 'commits'),
  ResearchTemplate('Gym', HabitType.binary, Icons.fitness_center, Color(0xFFF472B6)),
];
