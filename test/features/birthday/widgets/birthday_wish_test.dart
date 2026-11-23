import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/test_harness.dart';

void main() {
  const lea = Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(month: 12, day: 31),
  );

  late RecordingBirthdayRepository repository;
  late FakeShareService share;
  late List<Object?> haptics;
  late FakeContactLinkRepository links;
  late FakePhoneContactService phone;

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
    links = FakeContactLinkRepository();
    phone = FakePhoneContactService();
  });

  /// Les actions de [birthday] au jour [today] ; les vibrations demandées
  /// sont relevées dans [haptics].
  Future<void> pumpActions(
    WidgetTester tester, {
    required DateTime today,
    Birthday birthday = lea,
  }) async {
    haptics = recordHaptics(tester);
    await tester.pumpHarness(
      WishActions(birthday: birthday, onColor: Colors.white),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdayRepositoryProvider.overrideWithValue(repository),
        shareServiceProvider.overrideWithValue(share),
        contactLinkRepositoryProvider.overrideWithValue(links),
        phoneContactServiceProvider.overrideWithValue(phone),
      ],
    );
    // La lecture des liaisons du téléphone.
    await tester.pump();
  }

  group('Souhaiter', () {
    testWidgets('shares a ready message and marks the wish', (tester) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(share.shared, ['Bon anniversaire Léa ! 🎂']);
      expect(repository.wished, [('lea', 2026)]);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);
    });

    testWidgets("shares the person's own message when they have one", (
      tester,
    ) async {
      await pumpActions(
        tester,
        today: DateTime(2026, 12, 31),
        birthday: const Birthday(
          id: 'lea',
          name: 'Léa',
          surname: 'Martin',
          date: BirthDate(month: 12, day: 31),
          wishMessage: 'Joyeux anniversaire ma sœur !',
        ),
      );

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(share.shared, ['Joyeux anniversaire ma sœur !']);
    });

    testWidgets('changes nothing when the sheet is closed', (tester) async {
      share.outcome = ShareOutcome.dismissed;
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(repository.wished, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('says when the sheet cannot open', (tester) async {
      share.outcome = ShareOutcome.unavailable;
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(repository.wished, isEmpty);
      expect(
        find.text("Impossible d'ouvrir le partage. Réessayez."),
        findsOneWidget,
      );
    });

    testWidgets('waits for the open sheet before another one', (tester) async {
      share.pending = Completer();
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      final button = find.ancestor(
        of: find.text('Souhaiter'),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

      share.pending!.complete(ShareOutcome.dismissed);
      await tester.pump();

      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    });
  });

  testWidgets('marks the birthday of the day wished and undoes it', (
    tester,
  ) async {
    await pumpActions(tester, today: DateTime(2026, 12, 31, 18));

    await tester.tap(find.text('Déjà souhaité'));
    await tester.pump();

    expect(repository.wished, [('lea', 2026)]);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);

    // La snackbar finit d'entrer avant qu'on touche « Annuler ».
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pump();

    expect(repository.unwished, [('lea', 2026)]);
  });

  testWidgets('gives a belated wish to the birthday it belongs to', (
    tester,
  ) async {
    // Le 31 décembre, souhaité le 1er janvier : c'est l'anniversaire 2026.
    await pumpActions(tester, today: DateTime(2027));

    await tester.tap(find.text('Déjà souhaité'));
    await tester.pump();

    expect(repository.wished, [('lea', 2026)]);
  });

  testWidgets('leaves twice as long to undo with TalkBack', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpActions(tester, today: DateTime(2026, 12, 31));

    await tester.tap(find.text('Déjà souhaité'));
    await tester.pump();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      undoDelay * 2,
    );
  });

  testWidgets('the wished pill fits a row, under a button height', (
    tester,
  ) async {
    await tester.pumpHarness(
      const Center(child: WishedPill()),
      overrides: [currentUidProvider.overrideWithValue('fake-uid')],
    );

    expect(find.text('Souhaité'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(WishedPill)).height,
      lessThan(kMinInteractiveDimension),
    );
  });

  group('a person linked to a contact', () {
    setUp(() {
      links.links['fake-uid'] = {
        'lea': const ContactLink(number: '0611111111', contactName: 'Léa'),
      };
    });

    testWidgets('« Message » opens the SMS with the wish ready', (
      tester,
    ) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      expect(find.text('Souhaiter'), findsNothing);
      await tester.tap(find.text('Message'));
      await tester.pump();

      expect(phone.texts, [('0611111111', 'Bon anniversaire Léa ! 🎂')]);
      expect(share.shared, isEmpty);
      expect(repository.wished, [('lea', 2026)]);
      expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);
    });

    testWidgets('« Appeler » opens the dialer and counts as a wish', (
      tester,
    ) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.byTooltip('Appeler'));
      await tester.pump();

      expect(phone.dialed, ['0611111111']);
      expect(repository.wished, [('lea', 2026)]);
    });

    testWidgets('a wish started before the links are read goes by SMS', (
      tester,
    ) async {
      // L'action « Souhaiter » de la notification, app ouverte à froid :
      // rien n'a encore lu les liaisons du téléphone.
      links.pendingFetch = Completer();
      await tester.pumpHarness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => wishBirthday(context, lea),
            child: const Text('go'),
          ),
        ),
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 12, 31)),
          currentUidProvider.overrideWithValue('fake-uid'),
          birthdayRepositoryProvider.overrideWithValue(repository),
          shareServiceProvider.overrideWithValue(share),
          contactLinkRepositoryProvider.overrideWithValue(links),
          phoneContactServiceProvider.overrideWithValue(phone),
        ],
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      links.pendingFetch!.complete();
      await tester.pumpAndSettle();

      expect(phone.texts.single.$1, '0611111111');
      expect(share.shared, isEmpty);
    });

    testWidgets('« Autre app » keeps the share sheet', (tester) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Autre app'));
      await tester.pump();

      expect(share.shared, ['Bon anniversaire Léa ! 🎂']);
      expect(phone.texts, isEmpty);
    });

    testWidgets('says when no app can call', (tester) async {
      phone.opens = false;
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.byTooltip('Appeler'));
      await tester.pump();

      expect(
        find.text('Aucune app pour appeler ou écrire sur ce téléphone.'),
        findsOneWidget,
      );
      expect(repository.wished, isEmpty);
    });

    testWidgets('meets the tap target and label guidelines', (tester) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });
}
