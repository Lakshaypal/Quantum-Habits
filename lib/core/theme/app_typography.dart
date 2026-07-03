import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography: Inter for UI, Space Grotesk for display headings, JetBrains Mono
/// for numerics/labels (the "lab" feel).
abstract final class AppType {
  static TextTheme textTheme(Color base, Color muted) {
    return TextTheme(
      displaySmall: GoogleFonts.spaceGrotesk(
          fontSize: 30, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 22, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.3),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: base),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: base),
      titleSmall: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: base),
      bodyLarge: GoogleFonts.inter(fontSize: 15, color: base, height: 1.45),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: base, height: 1.4),
      bodySmall: GoogleFonts.inter(fontSize: 12.5, color: muted, height: 1.4),
      labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: base),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
      labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w500, color: muted, letterSpacing: 1.0),
    );
  }

  /// Monospaced numerics, e.g. streak counters and the heatmap legend.
  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
}
