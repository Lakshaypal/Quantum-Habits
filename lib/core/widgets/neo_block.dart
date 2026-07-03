import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Neobrutalist accent block: flat fill, hard border, offset hard shadow
/// (blurRadius 0). Used sparingly for emphasis — primary CTAs, milestone chips.
class NeoBlock extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? foreground;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const NeoBlock({
    super.key,
    required this.child,
    required this.color,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
    this.onTap,
    this.radius = Radii.sm,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.black.withValues(alpha: 0.85), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: 18),
            child: child,
          ),
        ),
      ),
    );
  }
}
