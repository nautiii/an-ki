import 'dart:typed_data';

import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/blossom_rain.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/person_header.dart';
import 'package:an_ki/features/birthday/widgets/person_reminders_tile.dart';
import 'package:an_ki/features/birthday/widgets/wish_years.dart';
import 'package:an_ki/features/birthday/widgets/wish_bubble.dart';
import 'package:an_ki/features/birthday/widgets/wish_message_section.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';

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
  final fr = lookupAppLocalizations(const Locale('fr'));
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  /// Léa, née le [month]/[day] 1990 (année inconnue sans [yearKnown]).
  Birthday lea({
    int month = 10,
    int day = 24,
    bool yearKnown = true,
    List<int> wishedYears = const [],
    Set<ReminderLead>? reminders,
    Uint8List? picture,
    String? wishMessage,
  }) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(year: yearKnown ? 1990 : null, month: month, day: day),
    categories: const ['fam'],
    wishedYears: wishedYears,
    reminders: reminders,
    picture: picture,
    wishMessage: wishMessage,
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
    Map<String, ContactLink> links = const {},
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
        contactLinkRepositoryProvider.overrideWithValue(
          FakeContactLinkRepository(links: {'fake-uid': links}),
        ),
        phoneContactServiceProvider.overrideWithValue(
          FakePhoneContactService(),
        ),
      ],
      routes: {
        AppRoutes.birthdays: (_) => const Text('Accueil'),
        AppRoutes.search: (context) => Text(
          'Recherche ${GoRouterState.of(context).uri.queryParameters[AppRoutes.searchCategoryParam]}',
        ),
      },
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

  /// Ce que TalkBack lit de l'en-tête : un seul nœud, dans l'ordre visuel.
  SemanticsNode header(WidgetTester tester) => tester.getSemantics(
    find
        .descendant(
          of: find.byType(PersonHeader),
          matching: find.byType(MergeSemantics),
        )
        .first,
  );

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
      expect(find.widgetWithText(ActionChip, 'Famille'), findsOneWidget);
      // Hors du jour J et du lendemain, rien à souhaiter.
      expect(find.text('Souhaiter'), findsNothing);
      // Jamais souhaitée : pas de section des vœux, rien à se reprocher.
      expect(find.byType(WishYears), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PersonRemindersTile),
          matching: find.text("Comme d'habitude"),
        ),
        findsOneWidget,
      );
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
      expect(
        header(tester),
        isSemantics(
          label: 'Léa Martin\n24 octobre\nDans 12 jours',
          isHeader: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the orbit read as the coming age', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        header(tester),
        isSemantics(
          label: 'Dans 12 jours\nLéa Martin\n24 octobre 1990\nAura 36 ans',
          isHeader: true,
        ),
      );
      // Le dessin et ses chiffres ne se lisent pas une seconde fois.
      expect(find.bySemanticsLabel('36'), findsNothing);
      semantics.dispose();
    });

    testWidgets('the day itself, celebrated in the header', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 12));

      Finder inHeader(Finder finder) =>
          find.descendant(of: find.byType(PersonHeader), matching: finder);
      expect(inHeader(find.text("Aujourd'hui 🎉")), findsOneWidget);
      expect(
        inHeader(find.text("fête ses 36 ans aujourd'hui")),
        findsOneWidget,
      );
      // L'âge en grand, sans orbite : la phrase le dit à TalkBack.
      expect(inHeader(find.text('36')), findsOneWidget);
      expect(find.byType(OrbitCountdown), findsNothing);
      expect(find.bySemanticsLabel('36'), findsNothing);
      // Le vœu se fait dans la carte, avec les pétales derrière.
      expect(inHeader(find.text('Souhaiter')), findsOneWidget);
      expect(inHeader(find.byType(BlossomRain)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('once the day is wished, « Souhaité » joins the sentence', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      expect(
        find.descendant(
          of: find.byType(PersonHeader),
          matching: find.byType(WishedPill),
        ),
        findsOneWidget,
      );
      expect(find.text('Souhaiter'), findsNothing);
    });

    testWidgets('no age on the day without a birth year', (tester) async {
      await pumpPage(tester, person: lea(day: 12, yearKnown: false));

      expect(find.text("fête son anniversaire aujourd'hui"), findsOneWidget);
      expect(find.text('ans'), findsNothing);
      expect(find.byType(OrbitCountdown), findsNothing);
    });

    testWidgets('the day before without a birth year, read « Demain »', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 13, yearKnown: false));

      expect(inOrbit('1'), findsOneWidget);
      expect(inOrbit('jour'), findsOneWidget);
      expect(find.text('Demain'), findsNothing);
      expect(header(tester).label, endsWith('\nDemain'));
      semantics.dispose();
    });

    testWidgets('tomorrow, the day before', (tester) async {
      await pumpPage(tester, person: lea(day: 13));

      expect(find.text('Demain'), findsOneWidget);
      expect(orbit(tester).daysLeft, 1);
      expect(find.byType(BlossomRain), findsNothing);
    });

    testWidgets('the day after, the age reached and the late wish', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 11));

      Finder inHeader(Finder finder) =>
          find.descendant(of: find.byType(PersonHeader), matching: finder);
      expect(inHeader(find.text('Hier')), findsOneWidget);
      expect(inHeader(find.text('a eu 36 ans')), findsOneWidget);
      // Ni orbite d'un an, ni fête : le vœu en retard est sous la carte.
      expect(find.byType(OrbitCountdown), findsNothing);
      expect(find.byType(BlossomRain), findsNothing);
      expect(inHeader(find.text('Souhaiter')), findsNothing);
      expect(find.text('Souhaiter'), findsOneWidget);
    });

    testWidgets('the day after, once wished, « Souhaité » in the header', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 11, wishedYears: [2026]));

      expect(find.text('Hier'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PersonHeader),
          matching: find.byType(WishedPill),
        ),
        findsOneWidget,
      );
      expect(find.text('Souhaiter'), findsNothing);
    });

    testWidgets('the groups as chips in their tone', (tester) async {
      await pumpPage(tester);

      final chip = tester.widget<ActionChip>(
        find.widgetWithText(ActionChip, 'Famille'),
      );
      final tones = family.tones(tester.element(find.byType(ActionChip)));
      expect(chip.side, BorderSide.none);
      expect(chip.color!.resolve({}), tones.container);
      expect(chip.labelStyle?.color, tones.onContainer);
    });

    testWidgets('the name as the page header, with 48 dp targets', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      expect(
        header(tester),
        isSemantics(
          label: "Aujourd'hui 🎉\nLéa Martin\nfête ses 36 ans aujourd'hui\nSouhaité",
          isHeader: true,
        ),
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

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      final suggestions = lea(day: 11).wishSuggestions(today);
      expect((suggestions.first as TemplateWish).belated, isTrue);
      expect(share.shared.single, wishTexts(fr, 'Léa', suggestions).first);
      expect(repository.wished, [('lea', 2026)]);
    });

    testWidgets('linked, the day itself: Message and Appeler once each', (
      tester,
    ) async {
      await pumpPage(
        tester,
        person: lea(day: 12),
        links: const {
          'lea': ContactLink(number: '0611111111', contactName: 'Léa'),
        },
      );

      expect(find.text('Message'), findsOneWidget);
      expect(find.byTooltip('Appeler'), findsOneWidget);
      expect(find.text('Appeler'), findsNothing);
      // La carte est là, sans ses propres boutons.
      expect(find.byTooltip('Options du contact'), findsOneWidget);
    });

    testWidgets('linked, the day after: Message and Appeler once each', (
      tester,
    ) async {
      await pumpPage(
        tester,
        person: lea(day: 11),
        links: const {
          'lea': ContactLink(number: '0611111111', contactName: 'Léa'),
        },
      );

      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
    });

    testWidgets('lists the years, the latest first', (tester) async {
      await pumpPage(tester, person: lea(wishedYears: [2024, 2026, 2025]));

      final years = tester
          .widgetList<Chip>(find.byType(Chip))
          .map((chip) => (chip.label as Text).data);
      expect(years, ['2026', '2025', '2024']);
    });

    testWidgets('undoes the wish of this year, with a way back', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2025, 2026]));

      expect(find.text('Souhaité'), findsOneWidget);
      // Seul le vœu de l'anniversaire en cours s'annule.
      expect(find.byTooltip('Retirer le vœu de 2025'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Retirer le vœu de 2026'));
      await tester.tap(find.byTooltip('Retirer le vœu de 2026'));
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

      await tester.ensureVisible(find.byTooltip('Retirer le vœu de 2026'));
      await tester.tap(find.byTooltip('Retirer le vœu de 2026'));
      await tester.pump();

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        undoDelay * 2,
      );
    });
  });

  group('reminders', () {
    /// Ouvre la feuille des rappels depuis leur ligne.
    Future<void> openReminders(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(PersonRemindersTile));
      await tester.tap(find.byType(PersonRemindersTile));
      await tester.pumpAndSettle();
    }

    testWidgets('sum up on one line', (tester) async {
      await pumpPage(
        tester,
        person: lea(reminders: {ReminderLead.weekBefore, ReminderLead.sameDay}),
      );

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('7 jours avant · Le jour\u00a0J'), findsOneWidget);
    });

    testWidgets('customised right away, from the usual cadence', (
      tester,
    ) async {
      await pumpPage(tester);
      await openReminders(tester);

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
      await openReminders(tester);

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
      await openReminders(tester);

      await tester.ensureVisible(find.text('Aucun'));
      await tester.tap(find.text('Aucun'));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [<ReminderLead>{}]);
    });

    testWidgets('a muted person goes back to the usual', (tester) async {
      await pumpPage(tester, person: lea(reminders: const {}));
      expect(find.text('Aucun rappel'), findsOneWidget);
      await openReminders(tester);

      expect(choice(tester, 'Aucun').selected, isTrue);
      await tester.ensureVisible(find.text("Comme d'habitude"));
      await tester.tap(find.text("Comme d'habitude"));
      await tester.pump();

      expect(reminderIds(), ['lea']);
      expect(reminderSets(), [isNull]);
    });
  });

  group('wish message', () {
    testWidgets('the default one, said so', (tester) async {
      await pumpPage(tester);

      await tester.ensureVisible(
        find.text('Proposé par AnKi, change chaque année'),
      );
      expect(
        find.text(suggestedWishText(fr, lea(), lea().wishSuggestions(today))),
        findsOneWidget,
      );
    });

    testWidgets('their own, customised from its sheet', (tester) async {
      await pumpPage(tester, person: lea(wishMessage: 'Coucou Léa'));

      expect(find.text('Message par défaut'), findsNothing);
      await tester.ensureVisible(find.text('Coucou Léa'));
      await tester.tap(find.text('Coucou Léa'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Bonne fête Léa',
      );
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.wishMessageUpdates, [('lea', 'Bonne fête Léa')]);
    });

    testWidgets('on the day, the bubble opens the others; one tap shares it', (
      tester,
    ) async {
      await pumpPage(tester, person: lea(day: 12));
      final texts = wishTexts(
        fr,
        'Léa',
        lea(day: 12).wishSuggestions(today, circle: WishCircle.family),
      );

      // Le message n'est qu'une fois sur la page : la bulle remplace la
      // section du message ce jour-là.
      expect(find.text(texts.first), findsOneWidget);
      expect(find.byType(WishMessageSection), findsNothing);

      await tester.tap(find.byType(WishBubble));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(OtherWishesSheet),
          matching: find.text(texts[1]),
        ),
      );
      await tester.pumpAndSettle();

      expect(share.shared, [texts[1]]);
      expect(repository.wished, [('lea', 2026)]);
    });

    testWidgets('once wished, the message section is back', (tester) async {
      await pumpPage(tester, person: lea(day: 12, wishedYears: [2026]));

      expect(find.byType(WishBubble), findsNothing);
      await tester.ensureVisible(find.byType(WishMessageSection));
      expect(find.byType(WishMessageSection), findsOneWidget);
    });

    testWidgets('their own, sent by « Souhaiter » on the day', (tester) async {
      await pumpPage(tester, person: lea(day: 12, wishMessage: 'Coucou Léa'));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(share.shared, ['Coucou Léa']);
    });
  });

  testWidgets('a group opens the search filtered on it', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Famille'));
    await tester.pumpAndSettle();

    expect(find.text('Recherche fam'), findsOneWidget);
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
