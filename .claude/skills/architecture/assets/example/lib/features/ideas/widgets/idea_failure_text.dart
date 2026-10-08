import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:an_ki/l10n/app_localizations.dart';

/// Message à afficher pour une erreur d'idée. Seule l'UI choisit les mots :
/// le domaine et l'état ne portent que des [IdeaFailure].
String ideaFailureText(AppLocalizations l10n, Object error) => switch (error) {
  IdeaFailure.invalidDraft => l10n.ideaFailureInvalid,
  IdeaFailure.signedOut => l10n.ideaFailureSignedOut,
  IdeaFailure.storage => l10n.ideaFailureStorage,
  _ => l10n.errorUnknown,
};
