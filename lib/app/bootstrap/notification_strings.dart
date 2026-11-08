import 'package:an_ki/app/bootstrap/app_locale.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/l10n/app_localizations.dart';

/// Textes des rappels dans la langue de l'app ([appLocaleProvider]), pour
/// l'app (`main()`) comme pour la tâche de fond.
final localizedNotificationStrings = notificationStringsProvider.overrideWith(
  (ref) => NotificationStrings.fromL10n(
    lookupAppLocalizations(ref.watch(appLocaleProvider)),
  ),
);
