import 'dart:io';

import 'package:an_ki/app/bootstrap/app_shortcuts.dart';
import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/services/app_shortcut_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';

final _fr = lookupAppLocalizations(const Locale('fr'));
final _en = lookupAppLocalizations(const Locale('en'));

/// Module de test qui offre [count] raccourcis.
AppModule _moduleWith(int count) => AppModule(
  id: 'many',
  alwaysOn: false,
  enabledByDefault: false,
  icon: Icons.star,
  selectedIcon: Icons.star,
  name: (_) => 'Many',
  description: (_) => 'Many',
  rootPath: '/many',
  buildBranch: (_) => StatefulShellBranch(routes: const []),
  shortcuts: [
    for (var i = 0; i < count; i++)
      ModuleShortcut(
        id: 'many$i',
        icon: 'ic_many',
        label: (_) => 'Many $i',
        run: (_, _) {},
      ),
  ],
);

void main() {
  group('appShortcuts', () {
    test('Ajouter then Rechercher for the birthdays, in French', () {
      expect(appShortcuts(modules: [birthdaysModule], l10n: _fr), const [
        AppShortcut(
          type: 'add',
          label: 'Ajouter un anniversaire',
          icon: 'ic_shortcut_add',
        ),
        AppShortcut(
          type: 'search',
          label: 'Rechercher',
          icon: 'ic_shortcut_search',
        ),
      ]);
    });

    test('adds the scanner when the books run, in English', () {
      final shortcuts = appShortcuts(
        modules: [birthdaysModule, booksModule],
        l10n: _en,
      );

      expect(shortcuts.map((s) => s.type), ['add', 'search', 'scan']);
      expect(shortcuts.map((s) => s.label), [
        'Add a birthday',
        'Search',
        'Scan a book',
      ]);
      expect(shortcuts.last.icon, 'ic_shortcut_scan');
    });

    test('keeps at most four', () {
      final shortcuts = appShortcuts(
        modules: [birthdaysModule, _moduleWith(5)],
        l10n: _fr,
      );

      expect(shortcuts, hasLength(maxAppShortcuts));
      expect(shortcuts.map((s) => s.type), ['add', 'search', 'many0', 'many1']);
    });

    test('every shortcut id of the registry is unique', () {
      final ids = [
        for (final module in appModules)
          for (final shortcut in module.shortcuts) shortcut.id,
      ];

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every icon is an Android resource, kept in release builds', () {
      const res = 'android/app/src/main/res';
      final keep = File('$res/raw/keep.xml').readAsStringSync();
      for (final module in appModules) {
        for (final shortcut in module.shortcuts) {
          expect(
            File('$res/drawable/${shortcut.icon}.xml').existsSync(),
            isTrue,
          );
          expect(
            File('$res/drawable-anydpi-v26/${shortcut.icon}.xml').existsSync(),
            isTrue,
          );
          expect(shortcut.icon, startsWith('ic_shortcut_'));
        }
      }
      expect(keep, contains('@drawable/ic_shortcut_*'));
    });

    test('the labels fit the launcher (25 characters)', () {
      for (final l10n in [_fr, _en]) {
        for (final shortcut in appShortcuts(modules: appModules, l10n: l10n)) {
          expect(shortcut.label.length, lessThanOrEqualTo(25));
        }
      }
    });
  });

  group('appShortcutsProvider', () {
    ProviderContainer container({String? uid, bool sessionKnown = true}) =>
        ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            authUserProvider.overrideWithValue(
              sessionKnown
                  ? AsyncData(uid == null ? null : fam.MockUser(uid: uid))
                  : const AsyncLoading(),
            ),
            runningModulesProvider.overrideWithValue([
              birthdaysModule,
              booksModule,
            ]),
            localeProvider.overrideWithValue(const Locale('fr')),
          ],
        );

    test('sets none while signed out', () {
      expect(container().read(appShortcutsProvider), isEmpty);
    });

    test('decides nothing while the session is restored', () {
      expect(
        container(uid: 'u1', sessionKnown: false).read(appShortcutsProvider),
        isNull,
      );
    });

    test('follows the running modules in the app language', () {
      final shortcuts = container(uid: 'u1').read(appShortcutsProvider);

      expect(shortcuts!.map((s) => s.label), [
        'Ajouter un anniversaire',
        'Rechercher',
        'Scanner un livre',
      ]);
    });

    test('the sync effect sets them on the service', () async {
      final service = FakeAppShortcutService();
      final c = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          authUserProvider.overrideWithValue(
            AsyncData(fam.MockUser(uid: 'u1')),
          ),
          runningModulesProvider.overrideWithValue([birthdaysModule]),
          localeProvider.overrideWithValue(const Locale('en')),
          appShortcutServiceProvider.overrideWithValue(service),
        ],
      );

      c.listen(appShortcutsSyncProvider, (_, _) {});
      await pumpEventQueue();

      expect(service.sets.single.map((s) => s.label), [
        'Add a birthday',
        'Search',
      ]);
    });
  });
}
