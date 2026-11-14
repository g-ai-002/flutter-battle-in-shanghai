import 'package:flutter/material.dart';

import '../utils/system_ui.dart';

/// 焦土夜色 + 火焰橙的视觉基调。
const Color appFlame = Color(0xFFC2452F);
const Color appGold = Color(0xFFD9A65A);

ThemeData buildLightTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: Color(0xFFA63A2B),
    onPrimary: Color(0xFFFFF8F2),
    primaryContainer: Color(0xFFF4DDD4),
    onPrimaryContainer: Color(0xFF5A1A10),
    secondary: Color(0xFF8A6A3F),
    onSecondary: Color(0xFFFFF8F2),
    surface: Color(0xFFFFFBF3),
    onSurface: Color(0xFF2B2620),
    surfaceContainerHighest: Color(0xFFF0E6D4),
    onSurfaceVariant: Color(0xFF7C7062),
    outline: Color(0xFFE0D3BE),
    outlineVariant: Color(0xFFEDE3D2),
    error: Color(0xFFB3261E),
    surfaceTint: Colors.transparent,
    tertiary: Color(0xFF4B6B5B),
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFFF5EDDD),
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFE2703A),
    onPrimary: Color(0xFF2A0F06),
    primaryContainer: Color(0xFF5A2318),
    onPrimaryContainer: Color(0xFFF8DCD2),
    secondary: Color(0xFFD3AE74),
    onSecondary: Color(0xFF2E2413),
    surface: Color(0xFF1F1A14),
    onSurface: Color(0xFFF0E6D6),
    surfaceContainerHighest: Color(0xFF2B241B),
    onSurfaceVariant: Color(0xFFA99C8A),
    outline: Color(0xFF3A3227),
    outlineVariant: Color(0xFF30291F),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF3A0A08),
    surfaceTint: Colors.transparent,
    tertiary: Color(0xFF9DB58A),
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFF14100C),
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  String? fontFamily,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    fontFamily: fontFamily,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyleFor(scaffoldColor),
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      side: BorderSide(color: colorScheme.outline),
      shape: const StadiumBorder(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.6),
      thickness: 0.6,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
