import 'package:flutter/material.dart';

import 'package:an_ki/l10n/app_localizations.dart';

/// Extension pour accéder facilement aux localizations
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
