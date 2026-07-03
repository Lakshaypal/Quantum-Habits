import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Calm gradient backdrop: soft accent "orbs" on deep space black. Gives the
/// frosted-glass panels something to blur, creating the premium depth.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) return ColoredBox(color: AppColors.lightBg, child: child);
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.deepSpace),
      child: Stack(
        children: [
          Positioned(top: -140, left: -90, child: _orb(AppColors.electricBlue, 380, 0.20)),
          Positioned(top: 160, right: -130, child: _orb(AppColors.softPurple, 340, 0.16)),
          Positioned(bottom: -160, left: 30, child: _orb(AppColors.warmAmber, 300, 0.10)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _orb(Color c, double size, double opacity) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c.withValues(alpha: opacity), c.withValues(alpha: 0)],
            ),
          ),
        ),
      );
}
