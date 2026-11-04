import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le 12 octobre 2026.
  final today = DateTime(2026, 10, 12);
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  /// Léa, née le [month]/[day] 1990 (année inconnue sans [yearKnown]).
  Birthday lea({
    int month = 10,
    int day = 24,
    bool yearKnown = true,
    List<int> wishedYears = const [],
    Set<ReminderLead>? reminders,
  }) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(year: yearKnown ? 1990 : null, month: month, day: day),
    categories: const ['fam'],
    wishedYears: wishedYears,
    reminders: reminders,
  );

  late RecordingBirthdayRepository repository;
  late ProviderContainer container;

  Future<void> pumpPage(
    WidgetTester tester, {
    AsyncValue<List<Birthday>>? birthdays,
    Birthday? person,
    String id = 'lea',
  }) => mockNetworkImages(() async {
    repository = RecordingBirthdayRepository();
    await tester.pumpHarness(
      PersonScreen(birthdayId: id),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdaysProvider.overrideWithValue(
          birthdays ?? AsyncData([person ?? lea()]),
        ),
        birthdayRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([family]),
        ),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserProfile(id: 'fake-uid', name: 'A', surname: 'B', locale: 'fr'),
          ),
        ),
        shareServiceProvider.overrideWithValue(FakeShareService()),
      ],
      routes: {AppRoutes.birthdays: (_) => const Text('Accueil')},
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(PersonScreen)),
    );
    // Le squelette respire sans fin : une frame suffit pendant le chargement.
    if (birthdays is AsyncLoading) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  });

  /// Rappels écrits, séparés : un record compare ses ensembles par identité.
  List<String> reminderIds() => [
    for (final (id, _) in repository.reminderUpdates) id,
  ];
  List<Set<ReminderLead>?> reminderSets() => [
    for (final (_, leads) in repository.reminderUpdates) leads,
  ];

  ChoiceChip choice(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  group('shows', () {
    testWidgets('who, when, how old and their groups', (tester) async {
      await pumpPage(tester);

      expect(find.text('Léa Martin'), findsOneWidget);
      expect(find.text('Dans 12 jours'), findsOneWidget);
      expect(find.text('24 octobre 1990'), findsOneWidget);
      expect(find.text('Aura 36 ans'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Famille'), findsOneWidget);
      // Hors du jour J et du lendemain, rien à souhaiter.
      expect(find.text('Souhaiter'), findsNothing);
      expect(find.text('Pas encore souhaité avec AnKi'), findsOneWidget);
      expect(choice(tester, "Comme d'habitude").selected, isTrue);
    });

    testWidgets('no age without a birth year', (tester) async {
      await pumpPage(tester, person: lea(yearKnown: false));

      expect(find.text('24 octobre'), findsOneWidget);
      expect(find.textContaining('Aura'), findsNothing);
    });

    testWidgets('the age reached on the day itself', (tester) async {
      await pumpPage(tester, person: lea(day: 12));

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(find.text('36 ans'), findsOneWidget);
    });

    testWidgets('the name as the page header, with 48 dp targets', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      expect(
        tester.getSemantics(find.text('Léa Martin')),
        isSemantics(label: 'Léa Martin', isHeader: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('wishes', () {
    testWidgets('the day itself, marked by hand', (tester) async {
      await pumpPage(tester, person: lea(day: 12));

      expect(find.text('Souhaiter'), findsOneWidget);
      await tester.tap(find.text('Déjà souhaité'));
      await tester.pump();

      expect(repository.wished, [('lea', 2026)]);
    });

    testWidgets('the day after, still', (tester) async {
      await pumpPage(tester, person: lea(day: 11));

      expect(find.text('Souhaiter'), findsOneWidget);
      expect(find.text('Hier'), findsNothing);
    });

    testWidgets('lists the years, the latest first', (tester) async {
      await pumpPage(tester, person: lea(wishedYears: [2024, 2026, 2025]));

      final rows = tester
          .widgetList<Text>(find.textContaining('Souhaité en'))
          .map((text) => text.data);
      expect(rows, [
        'Souhaité en 2026',
        'Souhaité en 2025',
        'Souhaité en 2024',
      ]);
    });

    testWidgets('undoes the wish of this year, with a way back', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2025, 2026]));

      expect(find.text('Souhaité'), findsOneWidget);
      // Seul le vœu de l'anniversaire en cours s'annule.
      expect(find.widgetWithText(TextButton, 'Retirer'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await tester.pumpAndSettle();

      expect(repository.unwished, [('lea', 2026)]);
      expect(find.text('Vœu de 2026 retiré'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SnackBarAction),
          matching: find.text('Annuler'),
        ),
      );
      await tester.pump();
      expect(repository.wished, [('lea', 2026)]);
    });
  });

  group('reminders', () {
    testWidgets('customised right away, from the usual cadence', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.ensureVisible(find.text('Personnalisés'));
      await tester.tap(find.text('Personnalisés'));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [
        {ReminderLead.weekBefore, ReminderLead.sameDay},
      ]);
    });

    testWidgets('one more lead for a person with their own', (tester) async {
      await pumpPage(
        tester,
        person: lea(reminders: {ReminderLead.weekBefore, ReminderLead.sameDay}),
      );

      expect(find.text('Le jour J est toujours prévenu.'), findsOneWidget);
      await tester.ensureVisible(find.text('La veille'));
      await tester.tap(find.text('La veille'));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [
        {ReminderLead.weekBefore, ReminderLead.sameDay, ReminderLead.dayBefore},
      ]);
    });

    testWidgets('a muted person goes back to the usual', (tester) async {
      await pumpPage(tester, person: lea(reminders: const {}));

      expect(choice(tester, 'Aucun').selected, isTrue);
      await tester.ensureVisible(find.text("Comme d'habitude"));
      await tester.tap(find.text("Comme d'habitude"));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [isNull]);
    });
  });

  testWidgets('« Modifier » opens the edit sheet', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(BirthdayFormSheet), findsOneWidget);
  });

  testWidgets('closes once the person is deleted', (tester) async {
    await pumpPage(tester);

    container.read(pendingDeletionsProvider.notifier).hide('lea');
    await tester.pumpAndSettle();

    expect(find.byType(PersonScreen), findsNothing);
  });

  testWidgets('deleted from the edit sheet, both close with « Annuler »', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.byType(BirthdayFormSheet), findsNothing);
    expect(find.byType(PersonScreen), findsNothing);
    expect(
      find.text("Léa Martin n'est plus dans vos anniversaires"),
      findsOneWidget,
    );
  });

  group('states', () {
    testWidgets('a skeleton while the list loads', (tester) async {
      await pumpPage(tester, birthdays: const AsyncLoading());

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byTooltip('Modifier'), findsNothing);
    });

    testWidgets('a person no longer there', (tester) async {
      await pumpPage(tester, id: 'gone');

      expect(find.text('Anniversaire introuvable'), findsOneWidget);
      expect(find.byTooltip('Modifier'), findsNothing);

      await tester.tap(find.text("Retour à l'accueil"));
      await tester.pumpAndSettle();
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('an error, with a retry', (tester) async {
      await pumpPage(
        tester,
        birthdays: AsyncError(Exception('offline'), StackTrace.empty),
      );

      expect(
        find.text("Impossible d'afficher cet anniversaire"),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
