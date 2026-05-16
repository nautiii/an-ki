import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final isDark = ref.watch(userProvider.select((s) => s.user?.isDark));

    if (isDark == null) {
      return ThemeMode.system;
    }
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  bool get isDark =>
      state == ThemeMode.dark ||
      (state == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  void toggle() {
    final newIsDark = !isDark;
    state = newIsDark ? ThemeMode.dark : ThemeMode.light;
    ref.read(userProvider.notifier).updateTheme(newIsDark);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
