import 'package:flutter/material.dart';

/// The journal types from the spec.
enum JournalKind { daily, reflection, gratitude, research, free }

extension JournalKindX on JournalKind {
  static JournalKind fromIndex(int i) =>
      JournalKind.values[i.clamp(0, JournalKind.values.length - 1)];

  String get label => switch (this) {
        JournalKind.daily => 'Daily',
        JournalKind.reflection => 'Reflection',
        JournalKind.gratitude => 'Gratitude',
        JournalKind.research => 'Research',
        JournalKind.free => 'Free Writing',
      };

  IconData get icon => switch (this) {
        JournalKind.daily => Icons.wb_sunny_outlined,
        JournalKind.reflection => Icons.self_improvement,
        JournalKind.gratitude => Icons.favorite_border,
        JournalKind.research => Icons.science_outlined,
        JournalKind.free => Icons.edit_outlined,
      };

  Color get color => switch (this) {
        JournalKind.daily => const Color(0xFFF4A340),
        JournalKind.reflection => const Color(0xFF8B7CF6),
        JournalKind.gratitude => const Color(0xFFF472B6),
        JournalKind.research => const Color(0xFF22D3EE),
        JournalKind.free => const Color(0xFF3B82F6),
      };

  String get prompt => switch (this) {
        JournalKind.daily => 'What happened today?',
        JournalKind.reflection => 'What did you learn about yourself?',
        JournalKind.gratitude => 'What are you grateful for?',
        JournalKind.research => 'Notes, findings, ideas…',
        JournalKind.free => 'Write freely…',
      };
}
