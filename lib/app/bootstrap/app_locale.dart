import 'package:an_ki/core/providers/device_locales_provider.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langue de l'app quand aucune autre n'est traduite.
const fallbackAppLocale = Locale('en');

/// Langue affichée par l'app et ses rappels ([resolveAppLocale]) : celle du
/// profil, sinon celle du téléphone. Vit dans `app/`, seul à connaître à la
/// fois le profil et les traductions.
final appLocaleProvider = Provider<Locale>(
  (ref) => resolveAppLocale(
    chosen: ref.watch(localeProvider),
    device: ref.watch(deviceLocalesProvider),
  ),
);

/// Première langue traduite parmi le choix du profil ([chosen]) puis les
/// langues du téléphone ([device]), dans leur ordre ; l'anglais sinon. Une
/// variante régionale (`fr_CA`) prend la langue (`fr`).
@visibleForTesting
Locale resolveAppLocale({
  required Locale? chosen,
  required List<Locale> device,
}) {
  final translated = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };
  for (final locale in [?chosen, ...device]) {
    if (translated.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return fallbackAppLocale;
}
