import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App locale, driven by the persisted user preference.
///
/// Lives in the `user` feature because its source of truth is the user
/// document; the `app/` layer watches it to configure [MaterialApp].
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final userLocale = ref.read(userProvider).user?.locale;

    ref.listen<String?>(userProvider.select((s) => s.user?.locale), (
      previous,
      next,
    ) {
      if (next != null) {
        state = Locale(next);
      }
    });

    if (userLocale != null) {
      return Locale(userLocale);
    }

    return const Locale('fr');
  }

  void setLocale(Locale locale) {
    state = locale;
    ref.read(userProvider.notifier).updateLocale(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
