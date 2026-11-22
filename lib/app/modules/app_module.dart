import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  /// servir qu'à un seul routeur (chaque `ProviderScope` crée le sien). Elle
  /// reçoit la clé du navigateur racine de ce routeur : une page du module
  /// qui doit couvrir les onglets la prend pour `parentNavigatorKey`.
  required final StatefulShellBranch Function(
    GlobalKey<NavigatorState> rootNavigatorKey,
  )
  buildBranch,

  /// Sa section des Réglages, posée par `app/` entre les préférences et la
  /// sécurité ; null s'il n'en a pas.
  final Widget? settingsSection,

  /// Son action la plus fréquente (ajouter, scanner), sous le pouce à côté
  /// de la barre ; null s'il n'en a pas.
  final ModuleAction? primaryAction,

  /// Ses raccourcis du lanceur (appui long sur l'icône de l'app), du plus
  /// fréquent au moins fréquent ; posés tant que le module est actif.
  final List<ModuleShortcut> shortcuts = const [],

  /// Providers que l'app garde en vie tant que le module est actif : un
  /// provider que personne n'écoute est mis en pause.
  final List<ProviderListenable<Object?>> effects = const [],

  /// Ses données utilisateur : effacées avec le compte et reprises avec un
  /// invité, que le module soit actif ou non ; null s'il n'en a pas.
  final ModuleData? data,
});

/// Action principale d'un module : le bouton flottant de son onglet.
class const ModuleAction({
  required final IconData icon,

  /// Ce que fait le bouton, lu par les lecteurs d'écran et en infobulle.
  required final String Function(AppLocalizations l10n) label,
  required final void Function(BuildContext context, WidgetRef ref) onPressed,
});

/// Raccourci du lanceur d'un module : l'app s'ouvre sur l'onglet du module,
/// puis [run] agit.
class const ModuleShortcut({
  /// Identifiant stable, unique parmi tous les modules : le lanceur le rend
  /// au toucher.
  required final String id,

  /// Ressource Android de son icône (`res/drawable/ic_shortcut_*`).
  required final String icon,

  /// Son libellé : le lanceur coupe le libellé long au-delà de 25
  /// caractères ; quick_actions le donne aussi comme libellé court (raccourci
  /// épinglé), où Android en conseille une dizaine.
  required final String Function(AppLocalizations l10n) label,

  /// Ce qu'il fait, l'onglet du module affiché.
  required final void Function(BuildContext context, WidgetRef ref) run,
});

/// Données utilisateur d'un module, pour la suppression du compte et la
/// reprise d'un invité (`moduleDataHooks`). Chaque crochet lit ses dépôts
/// dans le `ref` qu'il reçoit (`ref.watch`, à l'appel) et renvoie la fonction
/// qui agit. Cette fonction ne se sert jamais de `ref` : elle s'exécute plus
/// tard, après des `await`, quand ce `ref` peut ne plus être valable.
class const ModuleData({
  /// Effaceur de toutes les données du module pour un compte.
  required final UserDataEraser Function(Ref ref) eraser,

  /// Reprise d'invité du module ; null quand une feature la fait elle-même
  /// (les anniversaires et les groupes, avec leur plan de doublons).
  final GuestDataTransfer Function(Ref ref)? guestTransfer,
});
