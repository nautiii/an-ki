import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart' show basicLocaleListResolution;

/// Textes des rappels dans la langue du profil ([localeProvider]), pour l'app
/// (`main()`) comme pour la tâche de fond : une langue absente des
/// traductions se résout comme dans `MaterialApp`.
final localizedNotificationStrings = notificationStringsProvider.overrideWith((
  ref,
) {
  final locale = basicLocaleListResolution([
    ref.watch(localeProvider),
  ], AppLocalizations.supportedLocales);
  return NotificationStrings.fromL10n(lookupAppLocalizations(locale));
});
