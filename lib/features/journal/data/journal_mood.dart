import 'package:flutter/material.dart';

/// A 5-point mood attached to a journal entry. Stored inside the entry's
/// encrypted payload (so it never touches disk in plaintext and syncs for
/// free), and later correlated against habit completions.
enum Mood { rough, low, ok, good, great }

extension MoodX on Mood {
  static Mood? fromIndex(int? i) =>
      i == null ? null : Mood.values[i.clamp(0, Mood.values.length - 1)];

  /// 1..5, used for averaging in insights.
  int get score => index + 1;

  String get label => switch (this) {
        Mood.rough => 'Rough',
        Mood.low => 'Low',
        Mood.ok => 'Okay',
        Mood.good => 'Good',
        Mood.great => 'Great',
      };

  String get emoji => switch (this) {
        Mood.rough => '😔',
        Mood.low => '🙁',
        Mood.ok => '😐',
        Mood.good => '🙂',
        Mood.great => '😄',
      };

  Color get color => switch (this) {
        Mood.rough => const Color(0xFFE5484D),
        Mood.low => const Color(0xFFF4A340),
        Mood.ok => const Color(0xFF8A90A0),
        Mood.good => const Color(0xFF3B82F6),
        Mood.great => const Color(0xFF34D399),
      };
}
