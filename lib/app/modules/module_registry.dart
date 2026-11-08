import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
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

/// Modules actifs, dans l'ordre du registre : leurs onglets, leurs sections
/// des Réglages et leurs effets. Tant que l'utilisateur ne choisit pas ses
/// modules, tous ceux du registre.
final activeModulesProvider = Provider<List<AppModule>>(
  (ref) => ref.watch(appModulesProvider),
);
