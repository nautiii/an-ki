import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Chemins de toutes les routes de [routes], sous-routes comprises.
Iterable<String> _paths(List<RouteBase> routes, [String parent = '']) sync* {
  for (final route in routes) {
    if (route is! GoRoute) continue;
    final path = route.path.startsWith('/')
        ? route.path
        : '$parent/${route.path}';
    yield path;
    yield* _paths(route.routes, path);
  }
}

void main() {
  test('Birthdays then Books, in the order of their tabs', () {
    expect(
      [for (final module in appModules) module.id],
      ['birthdays', 'books'],
    );
    expect(birthdaysModule.rootPath, AppRoutes.birthdays);
    expect(booksModule.rootPath, AppRoutes.scanner);
  });

  test('each module has its own id and its own root path', () {
    final ids = [for (final module in appModules) module.id];
    final roots = [for (final module in appModules) module.rootPath];

    expect(ids.toSet(), hasLength(ids.length));
    expect(roots.toSet(), hasLength(roots.length));
  });

  test('the floating bar holds every module tab', () {
    // Un 5e module demande l'onglet « Plus » (D13), pas encore construit.
    expect(appModules.length, lessThanOrEqualTo(maxModuleTabs));
  });

  test('a module always on is on by default', () {
    for (final module in appModules.where((module) => module.alwaysOn)) {
      expect(module.enabledByDefault, isTrue, reason: module.id);
    }
    expect(birthdaysModule.alwaysOn, isTrue);
    expect(booksModule.alwaysOn, isFalse);
  });

  test('every page of a tab sits under its module root', () {
    for (final module in appModules) {
      final paths = _paths(module.buildBranch().routes).toList();
      expect(paths.first, module.rootPath, reason: module.id);
      for (final path in paths) {
        expect(
          path == module.rootPath || path.startsWith('${module.rootPath}/'),
          isTrue,
          reason: '${module.id} : $path',
        );
      }
    }
  });

  test('each router gets branches of its own', () {
    // La clé du navigateur d'une branche ne sert qu'à un routeur.
    for (final module in appModules) {
      expect(
        module.buildBranch().navigatorKey,
        isNot(module.buildBranch().navigatorKey),
        reason: module.id,
      );
    }
  });

  test('Birthdays keeps the reminders in sync while it is on', () {
    expect(birthdaysModule.effects, [reminderSyncProvider]);
    expect(booksModule.effects, isEmpty);
  });

  test('names and describes each module', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));

    expect(birthdaysModule.name(l10n), 'Anniversaires');
    expect(booksModule.name(l10n), 'Scanner');
    expect(
      birthdaysModule.description(l10n),
      'Qui fête quoi, et quand le souhaiter',
    );
    expect(
      booksModule.description(l10n),
      'Vos séries : le dernier tome, le prochain et sa date de sortie',
    );
  });

  test('every registered module is active', () {
    final container = ProviderContainer.test();

    expect(container.read(activeModulesProvider), appModules);
  });
}
