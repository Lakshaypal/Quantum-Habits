import 'package:flutter/widgets.dart';

/// Spacing scale (8pt-ish).
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radii — rounded, 12–24px per the design language.
abstract final class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
}

/// Motion tokens — all transitions stay under 250ms with a gentle curve.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}
