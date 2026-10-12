import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message de fin d'un import de contacts, ou null tant qu'il n'y a rien à
/// dire (avant l'import, pendant l'import).
String? contactImportMessage(AppLocalizations l10n, AsyncValue<int?> state) {
  return switch (state) {
    AsyncData(:final value?) =>
      value > 0 ? l10n.contactsImported(value) : l10n.noContactsWithBirthday,
    AsyncError(error: ContactImportFailure.permissionDenied) =>
      l10n.permissionDenied,
    AsyncError() => l10n.errorUnknown,
    _ => null,
  };
}
