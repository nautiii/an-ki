import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:flutter_riverpod/misc.dart';

/// Crochets de données des modules ([ModuleData]) pour la suppression du
/// compte et la reprise d'un invité : ceux de **tous** les modules du
/// registre, actifs ou non. Un module désactivé garde ses données : elles
/// partent avec le compte et suivent l'invité comme les autres.
///
/// Posés dans le `ProviderScope` de `main()`, et dans ceux des tests qui
/// suppriment un compte ou reprennent un invité.
final moduleDataHooks = <Override>[
  userDataErasersProvider.overrideWith(
    (ref) => [
      for (final module in ref.watch(appModulesProvider))
        if (module.data case final data?) data.eraser(ref),
    ],
  ),
  guestDataTransfersProvider.overrideWith(
    (ref) => [
      for (final module in ref.watch(appModulesProvider))
        if (module.data?.guestTransfer case final transfer?) transfer(ref),
    ],
  ),
];
