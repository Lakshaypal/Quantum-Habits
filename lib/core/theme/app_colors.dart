import 'package:flutter/widgets.dart';

/// Core color tokens for Quantum Habits. Dark-first; light is secondary.
abstract final class AppColors {
  // Base surfaces
  static const deepSpace = Color(0xFF0A0B0D); // app background
  static const graphite = Color(0xFF16181D); // panels
  static const graphiteHi = Color(0xFF1F232B); // raised surfaces

  // Text
  static const frostWhite = Color(0xFFF4F6FB); // primary text
  static const muted = Color(0xFF8A90A0); // secondary text
  static const faint = Color(0xFF5A6070); // tertiary text

  // Accents
  static const electricBlue = Color(0xFF3B82F6);
  static const softPurple = Color(0xFF8B7CF6);
  static const warmAmber = Color(0xFFF4A340);

  // Hairlines / borders
  static const border = Color(0x14FFFFFF); // white @ ~8%
  static const borderStrong = Color(0x26FFFFFF); // white @ ~15%

  // Light mode (secondary)
  static const lightBg = Color(0xFFF2F4F9);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF0A0B0D);
  static const lightMuted = Color(0xFF6B7280);

  /// Palette used to seed new habits with distinct, calm accent colors.
  static const habitSwatches = <Color>[
    electricBlue,
    softPurple,
    warmAmber,
    Color(0xFF34D399), // calm green
    Color(0xFFF472B6), // muted pink
    Color(0xFF22D3EE), // cyan
    Color(0xFFFB923C), // soft orange
    Color(0xFFA3E635), // lime
  ];
}
