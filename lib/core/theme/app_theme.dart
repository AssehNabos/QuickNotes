import 'package:flutter/material.dart';

/// Material 3 themes for QuickNotes, plus colour helpers for note cards.
///
/// Requires Flutter 3.27 or newer (uses `Color.withValues`).
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF3B6CF6);

  static const Color _lightScaffold = Color(0xFFF6F6F8);
  static const Color _darkScaffold = Color(0xFF111114);
  static const Color _darkCardBase = Color(0xFF1F2026);

  static const Color _lightNoteText = Color(0xFF1C1B1F);
  static const Color _darkNoteText = Color(0xFFEDEDF0);

  static const double cardRadius = 20;
  static const double inputRadius = 16;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final scaffold = isDark ? _darkScaffold : _lightScaffold;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  /// Background colour for a note card.
  ///
  /// Light mode uses the note's own colour as-is. Dark mode blends it into a
  /// dark base so the card stays comfortable at night while keeping a hint of
  /// the chosen colour.
  static Color noteBackground(int argb, Brightness brightness) {
    final base = Color(argb);
    if (brightness == Brightness.light) return base;
    return Color.alphaBlend(base.withValues(alpha: 0.16), _darkCardBase);
  }

  /// Text colour that contrasts with [noteBackground].
  static Color noteForeground(Brightness brightness) {
    return brightness == Brightness.light ? _lightNoteText : _darkNoteText;
  }

  /// Secondary text colour (dates, category labels) for note cards.
  static Color noteMutedForeground(Brightness brightness) {
    return noteForeground(brightness).withValues(alpha: 0.65);
  }
}
