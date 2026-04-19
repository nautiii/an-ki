import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Extension pour accéder facilement aux localizations
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}


