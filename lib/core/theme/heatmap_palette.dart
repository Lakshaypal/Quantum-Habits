import 'package:flutter/widgets.dart';

/// A 5-stop ramp (L0..L4) for the contribution heatmap. User-swappable —
/// this is the first customization hook the spec calls for.
class HeatmapPalette {
  final String name;
  final List<Color> levels; // length 5: L0 (none) .. L4 (perfect day)
  const HeatmapPalette(this.name, this.levels);

  Color levelColor(int level) => levels[level.clamp(0, 4)];

  static const frostBlue = HeatmapPalette('Frost Blue', [
    Color(0xFF14161B),
    Color(0xFF16324F),
    Color(0xFF1E5694),
    Color(0xFF2D7FE0),
    Color(0xFF5BA8FF),
  ]);

  static const softPurple = HeatmapPalette('Soft Purple', [
    Color(0xFF14161B),
    Color(0xFF2A2350),
    Color(0xFF4B3D9E),
    Color(0xFF6E5CE0),
    Color(0xFF9D8BFF),
  ]);

  static const warmAmber = HeatmapPalette('Warm Amber', [
    Color(0xFF14161B),
    Color(0xFF4A3517),
    Color(0xFF8A5E1E),
    Color(0xFFCF8A2E),
    Color(0xFFF4B95B),
  ]);

  static const githubGreen = HeatmapPalette('GitHub', [
    Color(0xFF14161B),
    Color(0xFF0E4429),
    Color(0xFF006D32),
    Color(0xFF26A641),
    Color(0xFF39D353),
  ]);

  static const all = <HeatmapPalette>[frostBlue, softPurple, warmAmber];
}
