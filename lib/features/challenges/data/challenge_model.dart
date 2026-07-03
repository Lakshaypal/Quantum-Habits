import 'package:flutter/material.dart';

enum ChallengeMode { strict, flexible }

extension ChallengeModeX on ChallengeMode {
  static ChallengeMode fromIndex(int i) => ChallengeMode.values[i.clamp(0, 1)];
  String get label => this == ChallengeMode.strict ? 'Strict' : 'Flexible';
  String get blurb => this == ChallengeMode.strict
      ? 'One missed day resets your progress.'
      : 'A few misses are allowed.';
}

/// Prefill presets for the create flow (from the spec's examples).
class ChallengeTemplate {
  final String name;
  final String description;
  final int days;
  final ChallengeMode mode;
  final int allowedMisses;
  final Color color;
  final IconData icon;
  const ChallengeTemplate({
    required this.name,
    required this.description,
    required this.days,
    required this.mode,
    this.allowedMisses = 0,
    required this.color,
    required this.icon,
  });
}

const kChallengeTemplates = <ChallengeTemplate>[
  ChallengeTemplate(
    name: '75 Hard',
    description: '75 days, no compromises.',
    days: 75,
    mode: ChallengeMode.strict,
    color: Color(0xFFF4A340),
    icon: Icons.local_fire_department_outlined,
  ),
  ChallengeTemplate(
    name: '100 Days of Code',
    description: 'Ship code every day.',
    days: 100,
    mode: ChallengeMode.flexible,
    allowedMisses: 5,
    color: Color(0xFF3B82F6),
    icon: Icons.code,
  ),
  ChallengeTemplate(
    name: '30 Days Reading',
    description: 'Read daily for a month.',
    days: 30,
    mode: ChallengeMode.flexible,
    allowedMisses: 3,
    color: Color(0xFF8B7CF6),
    icon: Icons.menu_book,
  ),
  ChallengeTemplate(
    name: 'Deep Work Sprint',
    description: 'Focused deep work, every day.',
    days: 21,
    mode: ChallengeMode.strict,
    color: Color(0xFF22D3EE),
    icon: Icons.bolt,
  ),
  ChallengeTemplate(
    name: 'Fitness Transformation',
    description: 'Train consistently for 90 days.',
    days: 90,
    mode: ChallengeMode.flexible,
    allowedMisses: 8,
    color: Color(0xFF34D399),
    icon: Icons.fitness_center,
  ),
];

/// Common durations offered as quick chips in the editor.
const kDurationPresets = <int>[7, 21, 30, 50, 75, 90, 100];
