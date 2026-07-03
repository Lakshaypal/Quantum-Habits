import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          surface: AppColors.graphite,
          surfaceContainerHighest: AppColors.graphiteHi,
          primary: AppColors.electricBlue,
          secondary: AppColors.softPurple,
          tertiary: AppColors.warmAmber,
          onSurface: AppColors.frostWhite,
        ),
        bg: AppColors.deepSpace,
        text: AppColors.frostWhite,
        muted: AppColors.muted,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          surface: AppColors.lightPanel,
          surfaceContainerHighest: Color(0xFFE9ECF3),
          primary: AppColors.electricBlue,
          secondary: AppColors.softPurple,
          tertiary: AppColors.warmAmber,
          onSurface: AppColors.lightText,
        ),
        bg: AppColors.lightBg,
        text: AppColors.lightText,
        muted: AppColors.lightMuted,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color bg,
    required Color text,
    required Color muted,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      textTheme: AppType.textTheme(text, muted),
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withValues(alpha: 0.03),
      dividerColor: AppColors.border,
      iconTheme: IconThemeData(color: text, size: 20),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
