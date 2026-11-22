import 'dart:async';

import 'package:an_ki/app/bootstrap/app_locale.dart';
import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/bootstrap/launch_request.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/app_shortcut_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raccourcis que le lanceur affiche au plus (Android en montre 4).
const maxAppShortcuts = 4;

/// Raccourcis du lanceur : « Souhaiter à … » pour [toWish] s'il y en a un,
/// puis ceux des modules [modules], dans l'ordre du registre puis celui de
/// chaque module, avec les libellés de [l10n] ; au plus [maxAppShortcuts].
/// Le raccourci de vœu ne montre que le prénom : le lanceur s'affiche sans
/// passer le verrou de l'app.
List<AppShortcut> appShortcuts({
  required List<AppModule> modules,
  required AppLocalizations l10n,
  Birthday? toWish,
}) => [
  if (toWish != null)
    AppShortcut(
      type: wishShortcutType(toWish.id),
      label: l10n.shortcutWish(toWish.name),
      icon: 'ic_shortcut_wish',
    ),
  for (final module in modules)
    for (final shortcut in module.shortcuts)
      AppShortcut(
        type: shortcut.id,
        label: shortcut.label(l10n),
        icon: shortcut.icon,
      ),
].take(maxAppShortcuts).toList(growable: false);

/// Raccourcis à poser : « Souhaiter à … » du jour, puis ceux des modules qui
/// tournent, dans la langue de l'app ; aucun hors session, car un raccourci
/// dynamique survit à la déconnexion. Verrouillée par l'empreinte, l'app garde
/// les siens : la session est la même. Null tant que Firebase restaure la
/// session ou que la liste charge : ce moment-là n'est pas une déconnexion ni
/// un carnet vide, et retirer les raccourcis au démarrage effacerait celui qui
/// vient de lancer l'app.
final appShortcutsProvider = Provider<List<AppShortcut>?>((ref) {
  final sessionKnown = ref.watch(
    authUserProvider.select((user) => user.hasValue || user.hasError),
  );
  if (!sessionKnown) return null;
  if (ref.watch(currentUidProvider) == null) return const [];
  if (ref.watch(birthdaysLoadingProvider)) return null;
  final modules = ref.watch(runningModulesProvider);
  return appShortcuts(
    modules: modules,
    l10n: lookupAppLocalizations(ref.watch(appLocaleProvider)),
    toWish: modules.contains(birthdaysModule)
        ? ref.watch(birthdaysListProvider).toWishNow(ref.watch(todayProvider))
        : null,
  );
});

/// Pose les raccourcis ([appShortcutsProvider]) à chaque changement :
/// session, modules, langue, anniversaires et jour ; rien tant qu'ils ne sont
/// pas connus. Activé par `App`, toujours monté.
final appShortcutsSyncProvider = Provider<void>((ref) {
  final shortcuts = ref.watch(appShortcutsProvider);
  if (shortcuts == null) return;
  unawaited(ref.watch(appShortcutServiceProvider).setShortcuts(shortcuts));
});
