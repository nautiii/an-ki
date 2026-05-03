import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeProvider extends StateNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.system);

  ThemeMode get themeMode => state;

  bool get isDark =>
      state == ThemeMode.dark ||
      (state == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  void toggle(BuildContext context) {
    final bool currentlyDark =
        state == ThemeMode.dark ||
        (state == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    state = currentlyDark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeProvider = StateNotifierProvider<ThemeProvider, ThemeMode>(
  (ref) => ThemeProvider(),
);
