import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_activation.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modules d'AnKi, dans l'ordre de leurs onglets : seul endroit qui les
/// connaît tous. Un nouveau module : son fichier dans `app/modules/` et une
/// ligne ici.
final appModules = <AppModule>[birthdaysModule, booksModule];

/// Onglets que la barre flottante peut tenir (S5). Un test du registre échoue
/// au-delà : un 5e module demande l'onglet « Plus » (D13).
const maxModuleTabs = 4;

/// Le registre, tel que `app/` le lit (routeur, coquille, effets) ; un test
/// peut en donner un autre.
final appModulesProvider = Provider<List<AppModule>>((ref) => appModules);

/// Modules actifs ([activeModuleIds]), dans l'ordre du registre ; null tant
/// que le profil charge, pour que le routeur attende avant de rediriger.
/// Hors session, les réglages par défaut : Anniversaires reste actif, et ses
/// rappels s'annulent à la déconnexion.
final activeModulesProvider = Provider<List<AppModule>?>((ref) {
  final ids = ref.watch(_activeModuleIdsProvider);
  if (ids == null) return null;
  return [
    for (final module in ref.watch(appModulesProvider))
      if (ids.contains(module.id)) module,
  ];
});

/// Modules qui tournent : les actifs, ou ceux toujours actifs tant que le
/// profil charge. La coquille, les sections des Réglages et les effets les
/// suivent, ainsi les rappels ne s'arrêtent jamais en attendant le profil.
final runningModulesProvider = Provider<List<AppModule>>(
  (ref) =>
      ref.watch(activeModulesProvider) ??
      [
        for (final module in ref.watch(appModulesProvider))
          if (module.alwaysOn) module,
      ],
);

/// Ids des modules actifs, ou null tant que le profil charge. Ne prévient que
/// d'un vrai changement : le profil émet aussi pour un pseudo ou un thème,
/// qui ne doivent pas reconstruire la coquille ni l'app.
final _activeModuleIdsProvider =
    NotifierProvider<_ActiveModuleIds, Set<String>?>(_ActiveModuleIds.new);

class _ActiveModuleIds extends Notifier<Set<String>?> {
  @override
  Set<String>? build() {
    final registry = ref.watch(appModulesProvider);
    final uid = ref.watch(currentUidProvider);
    final choices = uid == null
        ? const <String, bool>{}
        : _choicesOf(ref.watch(userProfileProvider), uid);
    return choices == null ? null : activeModuleIds(registry, choices);
  }

  @override
  bool updateShouldNotify(Set<String>? previous, Set<String>? next) =>
      previous == null || next == null
      ? previous != next
      : !setEquals(previous, next);
}

/// Choix des modules du compte [uid] dans [profile] ; null tant qu'il charge
/// (le profil d'un compte précédent, gardé pendant le chargement, ne compte
/// pas). Pas encore de document (premier lancement) ou profil illisible :
/// aucun choix, les réglages par défaut.
Map<String, bool>? _choicesOf(AsyncValue<UserProfile?> profile, String uid) {
  if (profile.value case final user? when user.id == uid) {
    return user.moduleChoices;
  }
  if (profile.hasError) return const {};
  if (profile.isLoading) return null;
  return const {};
}
