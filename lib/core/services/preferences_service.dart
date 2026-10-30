import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, typed wrapper around [SharedPreferences].
///
/// SharedPreferences is loaded once at startup (see `main.dart`) and injected
/// through Riverpod, so reads here are synchronous and never block the UI.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';

  /// Reads the saved theme. Falls back to [ThemeMode.system] when nothing has
  /// been saved or the stored value is unrecognised.
  ThemeMode loadThemeMode() {
    try {
      final stored = _prefs.getString(_themeModeKey);
      return switch (stored) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (e) {
      debugPrint('QuickNotes: could not read theme preference: $e');
      return ThemeMode.system;
    }
  }

  /// Persists the theme. Returns `false` if the write failed.
  Future<bool> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      return await _prefs.setString(_themeModeKey, value);
    } catch (e) {
      debugPrint('QuickNotes: could not save theme preference: $e');
      return false;
    }
  }
}
