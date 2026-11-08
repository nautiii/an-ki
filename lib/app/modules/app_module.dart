import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// Module d'AnKi : des features branchées comme un tout, que l'utilisateur
/// active ou non (décision D13). Seul `app/` connaît les modules : les
/// features ignorent qu'elles en font partie.
///
/// Une valeur de configuration, comparée par identité : chaque module est une
/// constante du registre (`module_registry.dart`).
class const AppModule({
  /// Clé stable du module, dans le profil : 'birthdays', 'books'.
  required final String id,

  /// Toujours actif : l'utilisateur ne peut pas le désactiver.
  required final bool alwaysOn,

  /// Actif tant que l'utilisateur n'a rien choisi pour lui.
  required final bool enabledByDefault,

  /// Icônes de son onglet, au repos et sélectionné.
  required final IconData icon,
  required final IconData selectedIcon,

  /// Nom du module, libellé de son onglet.
  required final String Function(AppLocalizations l10n) name,

  /// Ce que le module fait pour l'utilisateur, en une phrase.
  required final String Function(AppLocalizations l10n) description,

  /// Racine de son onglet, préfixe de ses pages.
  required final String rootPath,

  /// Construit la branche de son onglet. Une fonction plutôt qu'une branche :
  /// une `StatefulShellBranch` porte la clé de son navigateur, qui ne doit
  /// servir qu'à un seul routeur (chaque `ProviderScope` crée le sien).
  required final StatefulShellBranch Function() buildBranch,

  /// Sa section des Réglages, posée par `app/` entre les préférences et la
  /// sécurité ; null s'il n'en a pas.
  final Widget? settingsSection,

  /// Providers que l'app garde en vie tant que le module est actif : un
  /// provider que personne n'écoute est mis en pause.
  final List<ProviderListenable<Object?>> effects = const [],
});
