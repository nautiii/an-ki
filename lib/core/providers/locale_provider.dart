import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final locale = ref.watch(userProvider.select((s) => s.user?.locale));
    return locale != null ? Locale(locale) : const Locale('fr');
  }

  void setLocale(Locale locale) {
    state = locale;
    ref.read(userProvider.notifier).updateLocale(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
