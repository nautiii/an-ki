import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/add_birthday_sheet.dart';
import 'package:an_ki/features/books/screens/shelf_screen.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/probe_module.dart';

void main() {
  setUp(FakeMobileScannerPlatform.install);

  Finder barIcon(IconData icon) =>
      find.descendant(of: find.byType(BottomBar), matching: find.byIcon(icon));

  /// L'app connectée, ouverte sur l'onglet des anniversaires, avec un
  /// anniversaire au carnet et avec Livres activé : la barre et ses deux
  /// onglets.
  Future<void> pumpSignedIn(WidgetTester tester) async {
    await tester.pumpApp(
      profile: booksOnProfile,
      auth: FakeAuthRepository(user: MockUser()),
      birthdays: [
        Birthday(
          id: '1',
          name: 'Léa',
          surname: 'Martin',
          date: BirthDate.fromDate(DateTime(1990, 3, 12)),
        ),
      ],
    );
    await tester.settleApp();
  }

  testWidgets('opens on the birthdays tab and switches to the books', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.appRouter.state.matchedLocation, AppRoutes.birthdays);

      await tester.tap(barIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ShelfScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.appRouter.state.matchedLocation, AppRoutes.books);
    });
  });

  group('action under the thumb', () {
    testWidgets('« + » beside the bar opens the add sheet, on the form', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        final add = find.byTooltip('Ajouter un anniversaire');
        // À droite de la barre, à sa hauteur.
        final bar = tester.getRect(find.byType(BottomBar));
        expect(tester.getRect(add).left, greaterThan(bar.center.dx));
        expect(
          (tester.getCenter(add).dy - bar.center.dy).abs(),
          lessThan(AppSpacing.md),
        );

        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(AddBirthdaySheet), findsOneWidget);
        expect(find.byType(BirthdayFormSheet), findsOneWidget);
      });
    });

    testWidgets('on the books tab, the button scans', (tester) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Ajouter un anniversaire'), findsNothing);
        await tester.tap(find.byTooltip('Scanner un livre'));
        await tester.pumpAndSettle();
        expect(tester.appRouter.state.matchedLocation, AppRoutes.booksScan);
      });
    });
  });

  testWidgets('a sheet covers the floating bar instead of opening under it', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      await tester.tap(find.byTooltip('Ajouter un anniversaire'));
      await tester.pumpAndSettle();
      expect(find.byType(BirthdayFormSheet), findsOneWidget);

      // Rien de la barre ne reçoit plus les touchers : la feuille et son voile
      // passent devant.
      final bar = tester.renderObject(find.byType(BottomBar));
      final hits = tester
          .hitTestOnBinding(tester.getCenter(find.byType(BottomBar)))
          .path
          .map((entry) => entry.target);
      expect(hits, isNot(contains(bar)));
    });
  });

  testWidgets('a snackbar from a tab floats above the nav bar', (tester) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          .showSnackBar(const SnackBar(content: Text('Hello')));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(BottomBar)).top),
      );

      // Laisse la snackbar se fermer : aucun minuteur en attente.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a hidden tab stays mounted with its state', (tester) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);
      final home = tester.element(find.byType(HomeScreen));

      await tester.tap(barIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();
      // Caché, l'onglet des anniversaires n'est pas démonté.
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(barIcon(Icons.cake_outlined));
      await tester.pumpAndSettle();

      // Le même élément : l'onglet n'a pas été remonté, son état est intact.
      expect(tester.element(find.byType(HomeScreen)), same(home));
    });
  });

  testWidgets('switches at once when animations are disabled', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      await tester.tap(barIcon(Icons.auto_stories_outlined));
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(ShelfScreen),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  test('a tab knows its branch, even when another module is hidden', () {
    final probe = probeModule();
    final registry = [birthdaysModule, booksModule, probe];

    final tabs = shellTabs(registry, [probe, birthdaysModule]);

    // Ordre du registre, et l'index de branche de chaque onglet.
    expect([for (final tab in tabs) tab.module.id], ['birthdays', 'probe']);
    expect([for (final tab in tabs) tab.branch], [0, 2]);
    expect(shellTabs(registry, registry).map((tab) => tab.branch), [0, 1, 2]);
  });

  testWidgets('shows the active modules only and opens the right branch', (
    tester,
  ) async {
    final probe = probeModule();
    await mockNetworkImages(() async {
      await tester.pumpApp(
        auth: FakeAuthRepository(user: MockUser()),
        overrides: [
          appModulesProvider.overrideWithValue([
            birthdaysModule,
            booksModule,
            probe,
          ]),
          activeModulesProvider.overrideWithValue([birthdaysModule, probe]),
        ],
      );
      await tester.settleApp();

      expect(barIcon(Icons.cake_rounded), findsOneWidget);
      expect(barIcon(Icons.science_outlined), findsOneWidget);
      expect(barIcon(Icons.auto_stories_outlined), findsNothing);

      // 2e onglet de la barre, 3e branche du routeur.
      await tester.tap(barIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(tester.appRouter.state.matchedLocation, probeRoot);
      expect(find.text('Écran sonde'), findsOneWidget);
      expect(barIcon(Icons.science_rounded), findsOneWidget);

      await tester.tap(barIcon(Icons.cake_outlined));
      await tester.pumpAndSettle();
      expect(tester.appRouter.state.matchedLocation, AppRoutes.birthdays);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('modules turned on and off', () {
    /// Active ou désactive Livres comme l'écran Modules, par l'éditeur du
    /// profil.
    Future<void> setBooks(WidgetTester tester, {required bool enabled}) async {
      await ProviderScope.containerOf(tester.element(find.byType(App)))
          .read(userProfileEditorProvider.notifier)
          .setModuleEnabled('books', enabled: enabled);
      await tester.pumpAndSettle();
    }

    testWidgets('one module: no bar, the « + » alone in the corner, the '
        'content and snackbars above it', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
        await tester.settleApp();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(BottomBar), findsNothing);
        final add = tester.getRect(find.byTooltip('Ajouter un anniversaire'));
        expect(add.right, greaterThan(800 - 100));
        expect(add.bottom, greaterThan(1200 - 100));
        // La place du bouton seul, pas celle d'une barre.
        final padding = MediaQuery.paddingOf(
          tester.element(find.byType(HomeScreen)),
        ).bottom;
        expect(padding, 1200 - add.top);

        ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
            .showSnackBar(const SnackBar(content: Text('Hello')));
        await tester.pumpAndSettle();
        final snackBar = tester.getRect(find.byType(SnackBar));
        expect(snackBar.bottom, lessThanOrEqualTo(add.top));
        expect(snackBar.bottom, greaterThan(1200 - 200));

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('turned on, Books brings the bar with both tabs', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
        await tester.settleApp();

        await setBooks(tester, enabled: true);

        expect(barIcon(Icons.cake_rounded), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomBar),
            matching: find.text('Livres'),
          ),
          findsOneWidget,
        );
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(ShelfScreen), findsOneWidget);
      });
    });

    testWidgets('turned off, a visited Books tab is unmounted', (tester) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();
        await tester.tap(barIcon(Icons.cake_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(ShelfScreen, skipOffstage: false), findsOneWidget);

        await setBooks(tester, enabled: false);

        expect(find.byType(ShelfScreen, skipOffstage: false), findsNothing);
        expect(find.byType(BottomBar), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('turned off while on its tab, back on Birthdays', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();

        await setBooks(tester, enabled: false);

        expect(tester.appRouter.state.matchedLocation, AppRoutes.birthdays);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ShelfScreen, skipOffstage: false), findsNothing);
        // La coquille l'a quitté d'elle-même : rien à annoncer.
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    testWidgets('turned off under the settings, which stay open until '
        'closed', (tester) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Paramètres'));
        await tester.pumpAndSettle();

        await setBooks(tester, enabled: false);

        expect(find.byType(SettingsScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.appRouter.state.matchedLocation, AppRoutes.birthdays);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ShelfScreen, skipOffstage: false), findsNothing);
      });
    });

    testWidgets('turned on again, its tab opens at its root', (tester) async {
      await mockNetworkImages(() async {
        await pumpSignedIn(tester);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();
        await setBooks(tester, enabled: false);

        await setBooks(tester, enabled: true);
        await tester.tap(barIcon(Icons.auto_stories_outlined));
        await tester.pumpAndSettle();

        expect(tester.appRouter.state.matchedLocation, AppRoutes.books);
        expect(find.byType(ShelfScreen), findsOneWidget);
      });
    });
  });

  group('shownBranch', () {
    final tabs = shellTabs(
      [birthdaysModule, booksModule],
      [birthdaysModule, booksModule],
    );

    test('the current branch while its module runs', () {
      expect(shownBranch(tabs, 1), 1);
    });

    test('the first tab once it no longer runs', () {
      expect(shownBranch(tabs.sublist(0, 1), 1), 0);
    });
  });
}
