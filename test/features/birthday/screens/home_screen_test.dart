import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/guest_backup_card.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/agenda_tile.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

/// A birthday whose anniversary is [daysAhead] days from today.
Birthday _relative(
  int daysAhead, {
  required String id,
  required String name,
  required String surname,
}) {
  final today = DateTime.now();
  final target = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysAhead));
  return Birthday(
    id: id,
    name: name,
    surname: surname,
    date: BirthDate.fromDate(DateTime(1990, target.month, target.day)),
  );
}

void main() {
  // Lundi 12 octobre 2026, 20 h : « Bonsoir ».
  final evening = DateTime(2026, 10, 12, 20);

  Birthday onDay(int daysAhead, {required String id}) {
    final target = DateTime(
      evening.year,
      evening.month,
      evening.day + daysAhead,
    );
    return Birthday(
      id: id,
      name: 'Person$id',
      surname: 'X',
      date: BirthDate.fromDate(DateTime(1990, target.month, target.day)),
    );
  }

  List<dynamic> overrides({
    required List<Birthday> birthdays,
    bool isLoading = false,
    DateTime? now,
    RecordingCategoryRepository? categories,
  }) => [
    clockProvider.overrideWithValue(() => now ?? evening),
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(
      const AsyncData(
        UserProfile(id: 'fake-uid', name: 'A', surname: 'B', locale: 'fr'),
      ),
    ),
    birthdaysProvider.overrideWithValue(
      isLoading ? const AsyncLoading() : AsyncData(birthdays),
    ),
    categoryRepositoryProvider.overrideWithValue(
      categories ?? RecordingCategoryRepository(const []),
    ),
  ];

  // Héros dans 3 jours ; puis la semaine, novembre et janvier prochain.
  final agenda = [
    onDay(3, id: '1'),
    onDay(5, id: '2'),
    onDay(20, id: '3'),
    onDay(100, id: '4'),
  ];

  testWidgets('shows skeletons while loading', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: const [], isLoading: true),
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Vos anniversaires vivront ici'), findsNothing);
  });

  group('first run', () {
    Future<void> pumpEmpty(WidgetTester tester) => mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: const []),
        routes: {
          AppRoutes.contactImport: (_) =>
              const Scaffold(body: Text('Import route')),
        },
      );
      await tester.pumpAndSettle();
    });

    testWidgets('invites to bring in the contacts first', (tester) async {
      await pumpEmpty(tester);

      expect(find.text('Qui voulez-vous fêter ?'), findsOneWidget);
      expect(
        find.text("AnKi ne lit que les noms et les dates d'anniversaire."),
        findsOneWidget,
      );
      expect(find.text('Prochain anniversaire'), findsNothing);
      // Rien à chercher dans un carnet vide.
      expect(find.byTooltip('Rechercher'), findsNothing);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Choisir dans mes contacts'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import route'), findsOneWidget);
    });

    testWidgets('still adds someone by hand', (tester) async {
      await pumpEmpty(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Ajouter à la main'));
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayFormSheet), findsOneWidget);
    });
  });

  testWidgets('greets by the time of day', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonsoir, A'), findsOneWidget);

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda, now: DateTime(2026, 10, 12, 9)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonjour, A'), findsOneWidget);
  });

  testWidgets('greets a guest without a name', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: [
        ...overrides(birthdays: agenda),
        isGuestProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonsoir'), findsOneWidget);
  });

  group('notice from another feature', () {
    testWidgets('sits above the hero once someone is there', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(notice: Text('Avis')),
        overrides: overrides(birthdays: agenda),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avis'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Avis')).dy,
        lessThan(tester.getTopLeft(find.byType(NextBirthdayCard)).dy),
      );
    });

    testWidgets('stays off the empty home', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          const HomeScreen(notice: Text('Avis')),
          overrides: overrides(birthdays: const []),
        );
        await tester.pumpAndSettle();
      });

      expect(find.text('Avis'), findsNothing);
    });
  });

  group('guest backup', () {
    List<dynamic> guestOverrides(List<Birthday> birthdays) => [
      ...overrides(birthdays: birthdays),
      isGuestProvider.overrideWithValue(true),
    ];

    testWidgets('offers a guest to save, after the last month', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: guestOverrides(agenda),
      );
      await tester.pumpAndSettle();

      final card = find.byType(GuestBackupCard, skipOffstage: false);
      expect(card, findsOneWidget);
      expect(tester.widget<GuestBackupCard>(card).count, 4);
      // Sous le dernier mois de l'agenda, jamais devant.
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(
          tester.getTopLeft(find.text('Janvier 2027', skipOffstage: false)).dy,
        ),
      );
    });

    testWidgets('waits for three birthdays', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: guestOverrides(agenda.take(2).toList()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuestBackupCard, skipOffstage: false), findsNothing);
    });

    testWidgets('never shows for a saved account', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: agenda),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuestBackupCard, skipOffstage: false), findsNothing);
    });

    testWidgets('leaves the calendar alone', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: guestOverrides(agenda),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendrier'));
      await tester.pumpAndSettle();

      expect(find.byType(GuestBackupCard, skipOffstage: false), findsNothing);
    });
  });

  testWidgets('lists the agenda by period, the hero aside', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dans les 7 jours'), findsOneWidget);
    expect(find.text('Novembre', skipOffstage: false), findsOneWidget);
    expect(find.text('Janvier 2027', skipOffstage: false), findsOneWidget);
    // La personne du héros n'apparaît qu'une fois.
    expect(find.text('Person1 X'), findsOneWidget);
    expect(find.byType(AgendaTile, skipOffstage: false), findsNWidgets(3));
  });

  testWidgets('recalls yesterday between the hero and the views', (
    tester,
  ) async {
    final yesterday = onDay(-1, id: 'y');
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: [...agenda, yesterday]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hier'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Hier')).dy,
      greaterThan(tester.getBottomLeft(find.byType(NextBirthdayCard)).dy),
    );
    expect(
      tester.getBottomLeft(find.text('Hier')).dy,
      lessThan(tester.getTopLeft(find.text('Agenda')).dy),
    );
  });

  testWidgets('shows nothing more when the hero holds everyone', (
    tester,
  ) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: [onDay(3, id: '1')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Person1 X'), findsOneWidget);
    expect(find.byType(AgendaTile), findsNothing);
    expect(find.text('Dans les 7 jours'), findsNothing);
  });

  testWidgets('reads section titles as headers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Dans les 7 jours')),
      isSemantics(isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('switches between the agenda and the calendar', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.byType(BirthdayCalendar), findsOneWidget);
    expect(find.text('Dans les 7 jours'), findsNothing);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.byType(BirthdayCalendar), findsNothing);
    expect(find.text('Dans les 7 jours'), findsOneWidget);
  });

  testWidgets('the app bar opens the search, the form and the settings', (
    tester,
  ) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
      routes: {
        AppRoutes.search: (_) => const Text('Search route'),
        AppRoutes.settings: (_) => const Text('Settings route'),
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajouter un anniversaire'));
    await tester.pumpAndSettle();
    expect(find.byType(BirthdayFormSheet), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    expect(find.text('Search route'), findsOneWidget);
  });

  testWidgets('the avatar opens the settings', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
      routes: {AppRoutes.settings: (_) => const Text('Settings route')},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text('Settings route'), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds together on a small phone at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overrides(birthdays: agenda),
    );
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dans les 7 jours', skipOffstage: false), findsOneWidget);
  });

  testWidgets('announces a failed group write', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(
          birthdays: const [],
          categories: RecordingCategoryRepository(
            const [],
            failure: Exception('rules'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );

      container
          .read(categoryEditorProvider.notifier)
          .create('Voisins', icon: 1, tone: 4);
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Impossible d'enregistrer le groupe. Vérifiez votre connexion et "
          'réessayez.',
        ),
        findsOneWidget,
      );
    });
  });

  // Anniversaires lus par le vrai provider depuis un dépôt factice :
  // suppression par glissement et ses échecs.
  group('birthdays from the repository', () {
    // The closest birthday is rendered in the "next birthday" card and excluded
    // from the scrollable list, so we always provide a second, farther one.
    final next = _relative(5, id: 'next', name: 'Alice', surname: 'Wonderland');
    final listed = _relative(40, id: 'listed', name: 'Bob', surname: 'Builder');

    List<dynamic> overridesWith(RecordingBirthdayRepository repository) => [
      currentUidProvider.overrideWithValue('fake-uid'),
      userProfileProvider.overrideWithValue(
        const AsyncData(
          UserProfile(id: 'fake-uid', name: 'A', surname: 'B', locale: 'fr'),
        ),
      ),
      birthdayRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
    ];

    testWidgets('HomeScreen lists non-next birthdays', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(
          RecordingBirthdayRepository(initial: [next, listed]),
        ),
      );
      await tester.pumpAndSettle();

      // "Alice" appears in the next-birthday card, "Bob" in the list below.
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
    });

    testWidgets('swiping left hides the birthday and offers undo', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(initial: [next, listed]);

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Bob Builder'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Bob Builder'), findsNothing);
      expect(
        find.text("Bob Builder n'est plus dans vos anniversaires"),
        findsOneWidget,
      );
      expect(repository.deleted, isEmpty);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Bob Builder'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
    });

    testWidgets('the deletion is written once the undo delay is over', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(initial: [next, listed]);

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Bob Builder'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repository.deleted, ['listed']);
    });

    testWidgets('a failed delete brings the birthday back and says so', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(
        initial: [next, listed],
        failure: Exception('denied'),
      );

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Bob Builder'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // Ce qui s'est passé et quoi faire, pas un « Erreur lors de … ».
      expect(
        find.text(
          "Votre modification n'a pas pu être enregistrée. Vérifiez votre "
          'connexion et réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.text('Bob Builder'), findsOneWidget);
      // Laisse la snackbar d'erreur se fermer.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('screen readers delete through the tile action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = RecordingBirthdayRepository(initial: [next, listed]);

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('Bob Builder')),
        const CustomSemanticsAction(label: 'Supprimer'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Bob Builder n'est plus dans vos anniversaires"),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(repository.deleted, ['listed']);
      semantics.dispose();
    });
  });
}
