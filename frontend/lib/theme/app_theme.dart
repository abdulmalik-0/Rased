import 'package:flutter/material.dart';

/// Semantic colors for Rased, provided as a ThemeExtension so widgets work in
/// both dark and light mode via `context.colors`.
@immutable
class RasedColors extends ThemeExtension<RasedColors> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color primary;
  final Color accent;
  final Color warning;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;

  const RasedColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.primary,
    required this.accent,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const dark = RasedColors(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceElevated: Color(0xFF21262D),
    border: Color(0xFF30363D),
    primary: Color(0xFF58A6FF),
    accent: Color(0xFF3FB950),
    warning: Color(0xFFD29922),
    danger: Color(0xFFF85149),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
  );

  static const light = RasedColors(
    background: Color(0xFFF6F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEFF2F5),
    border: Color(0xFFD0D7DE),
    primary: Color(0xFF0969DA),
    accent: Color(0xFF1A7F37),
    warning: Color(0xFF9A6700),
    danger: Color(0xFFCF222E),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0xFF656D76),
  );

  @override
  RasedColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? primary,
    Color? accent,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return RasedColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  RasedColors lerp(ThemeExtension<RasedColors>? other, double t) {
    if (other is! RasedColors) return this;
    return RasedColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension RasedColorsX on BuildContext {
  RasedColors get colors =>
      Theme.of(this).extension<RasedColors>() ?? RasedColors.dark;
}

class AppTheme {
  static ThemeData dark() => _build(RasedColors.dark, Brightness.dark);
  static ThemeData light() => _build(RasedColors.light, Brightness.light);

  static ThemeData _build(RasedColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF0D1117)
            : Colors.white,
        secondary: c.accent,
        onSecondary: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.danger,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        labelStyle: TextStyle(color: c.textSecondary),
      ),
      dividerColor: c.border,
      useMaterial3: true,
      extensions: [c],
    );
  }
}
