import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_activation.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/probe_module.dart';

/// Module de test actif par défaut, racine `/gifts`.
final _gifts = AppModule(
  id: 'gifts',
  alwaysOn: false,
  enabledByDefault: true,
  icon: Icons.redeem_outlined,
  selectedIcon: Icons.redeem_rounded,
  name: (_) => 'Cadeaux',
  description: (_) => 'Des idées',
  rootPath: '/gifts',
  buildBranch: () => StatefulShellBranch(
    routes: [GoRoute(path: '/gifts', builder: (_, _) => const SizedBox())],
  ),
);

void main() {
  final registry = [birthdaysModule, booksModule, _gifts];

  group('activeModuleIds', () {
    test('without a choice, the defaults: Birthdays on, Books off', () {
      expect(activeModuleIds(registry, const {}), {'birthdays', 'gifts'});
    });

    test('an explicit choice wins over the default', () {
      expect(activeModuleIds(registry, const {'books': true, 'gifts': false}), {
        'birthdays',
        'books',
      });
    });

    test('a module always on stays on, whatever the choice', () {
      expect(
        activeModuleIds(registry, const {'birthdays': false}),
        contains('birthdays'),
      );
    });

    test('keeps the registry order and ignores unknown ids', () {
      final ids = activeModuleIds(registry, const {
        'books': true,
        'films': true,
      });

      expect(ids.toList(), ['birthdays', 'books', 'gifts']);
    });
  });

  group('moduleRedirect', () {
    final probe = probeModule();
    final all = [birthdaysModule, booksModule, probe];

    test('sends a path of an inactive module to the first active root', () {
      final redirect = moduleRedirect(all, [
        birthdaysModule,
      ], AppRoutes.scanner);

      expect(redirect?.location, AppRoutes.birthdays);
      expect(redirect?.module, booksModule);
    });

    test('covers the pages under the module root, not a lookalike', () {
      expect(
        moduleRedirect(all, [birthdaysModule], '$probeRoot/detail/1')?.module,
        probe,
      );
      expect(moduleRedirect(all, [birthdaysModule], '${probeRoot}s'), isNull);
    });

    test('the first active module may not be Birthdays', () {
      expect(
        moduleRedirect(
          [booksModule, probe],
          [probe],
          AppRoutes.scanner,
        )?.location,
        probeRoot,
      );
    });

    test('leaves a path of an active module or of no module alone', () {
      final active = [birthdaysModule, booksModule];

      expect(moduleRedirect(all, active, AppRoutes.scanner), isNull);
      expect(moduleRedirect(all, active, AppRoutes.settings), isNull);
      expect(moduleRedirect(all, active, AppRoutes.person('1')), isNull);
    });

    test('waits while the activation is unknown', () {
      expect(moduleRedirect(all, null, AppRoutes.scanner), isNull);
    });

    test('has nowhere to go without an active module', () {
      expect(moduleRedirect(all, const [], AppRoutes.scanner), isNull);
    });
  });
}
