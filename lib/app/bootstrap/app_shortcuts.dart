import 'dart:async';

import 'package:an_ki/app/bootstrap/app_locale.dart';
import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/services/app_shortcut_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raccourcis que le lanceur affiche au plus (Android en montre 4).
const maxAppShortcuts = 4;

/// Raccourcis du lanceur des modules [modules], dans l'ordre du registre puis
/// celui de chaque module, avec les libellés de [l10n] ; au plus
/// [maxAppShortcuts].
List<AppShortcut> appShortcuts({
  required List<AppModule> modules,
  required AppLocalizations l10n,
}) => [
  for (final module in modules)
    for (final shortcut in module.shortcuts)
      AppShortcut(
        type: shortcut.id,
        label: shortcut.label(l10n),
        icon: shortcut.icon,
      ),
].take(maxAppShortcuts).toList(growable: false);

/// Raccourcis à poser : ceux des modules qui tournent, dans la langue de
/// l'app ; aucun hors session, car un raccourci dynamique survit à la
/// déconnexion. Verrouillée par l'empreinte, l'app garde les siens : la
/// session est la même. Null tant que Firebase restaure la session : ce
/// moment-là n'est pas une déconnexion, et retirer les raccourcis au
/// démarrage effacerait celui qui vient de lancer l'app.
final appShortcutsProvider = Provider<List<AppShortcut>?>((ref) {
  final sessionKnown = ref.watch(
    authUserProvider.select((user) => user.hasValue || user.hasError),
  );
  if (!sessionKnown) return null;
  if (ref.watch(currentUidProvider) == null) return const [];
  return appShortcuts(
    modules: ref.watch(runningModulesProvider),
    l10n: lookupAppLocalizations(ref.watch(appLocaleProvider)),
  );
});

/// Pose les raccourcis ([appShortcutsProvider]) à chaque changement :
/// session, modules, langue ; rien tant que la session est inconnue. Activé
/// par `App`, toujours monté.
final appShortcutsSyncProvider = Provider<void>((ref) {
  final shortcuts = ref.watch(appShortcutsProvider);
  if (shortcuts == null) return;
  unawaited(ref.watch(appShortcutServiceProvider).setShortcuts(shortcuts));
});
