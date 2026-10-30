import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Holds the current [ThemeMode] and persists every change.
///
/// The initial value is read synchronously from SharedPreferences, so the
/// saved theme is applied on the very first frame with no flash.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(preferencesServiceProvider).loadThemeMode();
  }

  /// Switches the theme and saves the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesServiceProvider).saveThemeMode(mode);
  }

  /// Convenience toggle used by a simple light/dark switch.
  ///
  /// When the current mode is [ThemeMode.system], the brightness the device is
  /// currently showing is used as the starting point.
  Future<void> toggle(Brightness currentBrightness) {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => currentBrightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    };
    return setThemeMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
