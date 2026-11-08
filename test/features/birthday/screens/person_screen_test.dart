import 'dart:typed_data';

import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
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
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

/// Anniversaires illisibles à la première lecture (réseau coupé), lus
/// ensuite.
class _FlakyBirthdays extends RecordingBirthdayRepository {
  _FlakyBirthdays({super.initial});

  var _reads = 0;

  @override
  Stream<List<Birthday>> watchBirthdays(String uid) => _reads++ == 0
      ? Stream.error(Exception('offline'))
      : super.watchBirthdays(uid);
}

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
    Uint8List? picture,
  }) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(year: yearKnown ? 1990 : null, month: month, day: day),
    categories: const ['fam'],
    wishedYears: wishedYears,
    reminders: reminders,
    picture: picture,
  );

  late RecordingBirthdayRepository repository;
  late FakeShareService share;

  /// La page de [id] sur la liste [birthdays] (Léa seule par défaut), ou sur
  /// celle que [source] sert au vrai provider.
  Future<void> pumpPage(
    WidgetTester tester, {
    AsyncValue<List<Birthday>>? birthdays,
    Birthday? person,
    String id = 'lea',
    RecordingBirthdayRepository? source,
  }) => mockNetworkImages(() async {
    repository = source ?? RecordingBirthdayRepository();
    share = FakeShareService();
    await tester.pumpHarness(
      PersonScreen(birthdayId: id),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        if (source == null)
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
        shareServiceProvider.overrideWithValue(share),
      ],
      routes: {AppRoutes.birthdays: (_) => const Text('Accueil')},
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

  OrbitCountdown orbit(WidgetTester tester) =>
      tester.widget<OrbitCountdown>(find.byType(OrbitCountdown));
  Finder inOrbit(String text) => find.descendant(
    of: find.byType(OrbitCountdown),
    matching: find.text(text),
  );
  Finder inOrbitIcon(IconData icon) => find.descendant(
    of: find.byType(OrbitCountdown),
    matching: find.byIcon(icon),
  );
  AnKiColors colorsOf(WidgetTester tester) =>
      tester.element(find.byType(OrbitCountdown)).ankiColors;

  ChoiceChip choice(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  group('shows', () {
    testWidgets('who, with their photo, when, how old and their groups', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(picture: transparentPng));

      expect(find.text('Léa Martin'), findsOneWidget);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        MemoryImage(transparentPng),
      );
      expect(find.text('Dans 12 jours'), findsOneWidget);
      expect(find.text('24 octobre 1990'), findsOneWidget);
      // L'âge à venir, dans l'orbite.
      expect(orbit(tester).daysLeft, 12);
      expect(inOrbit('36'), findsOneWidget);
      expect(inOrbit('ans'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Famille'), findsOneWidget);
      // Hors du jour J et du lendemain, rien à souhaiter.
      expect(find.text('Souhaiter'), findsNothing);
      expect(find.text('Pas encore souhaité avec AnKi'), findsOneWidget);
      expect(choice(tester, "Comme d'habitude").selected, isTrue);
    });

    testWidgets('the days in the orbit, no age, without a birth year', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(yearKnown: false));

      expect(find.text('24 octobre'), findsOneWidget);
      expect(inOrbit('12'), findsOneWidget);
      expect(inOrbit('jours'), findsOneWidget);
      // Déjà dans l'orbite : pas répété en dessous, mais lu par TalkBack.
      expect(find.text('Dans 12 jours'), findsNothing);
      expect(find.bySemanticsLabel('Dans 12 jours'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Aura')), findsNothing);
      semantics.dispose();
    });

    testWidgets('the orbit read as the coming age', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester);

      expect(find.bySemanticsLabel('Aura 36 ans'), findsOneWidget);
      // Le dessin et ses chiffres ne se lisent pas une seconde fois.
      expect(find.bySemanticsLabel('36'), findsNothing);
      semantics.dispose();
    });

    testWidgets('the age reached on the day itself, the orbit closed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 12));

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(inOrbit('36'), findsOneWidget);
      expect(find.bySemanticsLabel('36 ans'), findsOneWidget);
      expect(orbit(tester).daysLeft, 0);
      expect(orbit(tester).arcColor, colorsOf(tester).blossom.color);
      semantics.dispose();
    });

    testWidgets('the orbit turns mint once the day is wished', (tester) async {
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      expect(orbit(tester).arcColor, colorsOf(tester).success.color);
      expect(inOrbit('36'), findsOneWidget);
    });

    testWidgets('a cake on the day without a birth year', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 12, yearKnown: false));

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(inOrbitIcon(Icons.cake_rounded), findsOneWidget);
      // L'orbite muette : « Aujourd'hui » ne se lit qu'une fois, sous elle.
      expect(find.bySemanticsLabel(RegExp("^Aujourd'hui")), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the day before without a birth year, read « Demain »', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 13, yearKnown: false));

      expect(inOrbit('1'), findsOneWidget);
      expect(inOrbit('jour'), findsOneWidget);
      expect(find.text('Demain'), findsNothing);
      expect(find.bySemanticsLabel('Demain'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a check once wished, without a birth year', (tester) async {
      await pumpPage(
        tester,
        person: lea(day: 12, yearKnown: false, wishedYears: [2026]),
      );

      expect(inOrbitIcon(Icons.check_rounded), findsOneWidget);
      expect(orbit(tester).arcColor, colorsOf(tester).success.color);
    });

    testWidgets('tomorrow, the day before', (tester) async {
      await pumpPage(tester, person: lea(day: 13));

      expect(find.text('Demain'), findsOneWidget);
      expect(orbit(tester).arcColor, isNull);
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

    testWidgets('the day after, still, with a late wish', (tester) async {
      await pumpPage(tester, person: lea(day: 11));

      expect(find.text('Hier'), findsNothing);
      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(share.shared.single, contains('avec un jour de retard'));
      expect(repository.wished, [('lea', 2026)]);
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

    testWidgets('leaves twice as long to undo with TalkBack', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await tester.pump();

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        undoDelay * 2,
      );
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

    testWidgets('one lead more or less for a person with their own', (
      tester,
    ) async {
      await pumpPage(
        tester,
        person: lea(reminders: {ReminderLead.weekBefore, ReminderLead.sameDay}),
      );

      expect(find.text('Le jour J est toujours prévenu.'), findsOneWidget);
      await tester.ensureVisible(find.text('La veille'));
      await tester.tap(find.text('La veille'));
      await tester.pump();
      await tester.tap(find.text('7 jours avant'));
      await tester.pump();

      expect(reminderIds(), ['lea', 'lea']);
      expect(reminderSets(), [
        {ReminderLead.weekBefore, ReminderLead.sameDay, ReminderLead.dayBefore},
        {ReminderLead.sameDay},
      ]);
    });

    testWidgets('mutes a person with « Aucun »', (tester) async {
      await pumpPage(tester);

      await tester.ensureVisible(find.text('Aucun'));
      await tester.tap(find.text('Aucun'));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [<ReminderLead>{}]);
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

    testWidgets('an error, then the person once read again', (tester) async {
      await pumpPage(tester, source: _FlakyBirthdays(initial: [lea()]));
      expect(
        find.text("Impossible d'afficher cet anniversaire"),
        findsOneWidget,
      );

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Léa Martin'), findsOneWidget);
    });
  });
}
