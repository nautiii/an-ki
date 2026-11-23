import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/wish_bubble.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  // Léa a 30 ans aujourd'hui.
  final today = DateTime(2026, 12, 31);
  const lea = Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(year: 1996, month: 12, day: 31),
  );
  final texts = wishTexts(
    lookupAppLocalizations(const Locale('fr')),
    lea.name,
    lea.wishSuggestions(today),
  );

  late RecordingBirthdayRepository repository;
  late FakeShareService share;

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
  });

  /// Les actions du héros ; [shown] à faux les retire (minuit, vœu fait
  /// ailleurs), feuille ouverte comprise.
  Future<void> pumpActions(WidgetTester tester, {ValueNotifier<bool>? shown}) =>
      tester.pumpHarness(
        ValueListenableBuilder<bool>(
          valueListenable: shown ?? ValueNotifier(true),
          builder: (_, visible, _) => visible
              ? const WishActions(birthday: lea, onColor: Colors.white)
              : const SizedBox.shrink(),
        ),
        overrides: [
          clockProvider.overrideWithValue(() => today),
          currentUidProvider.overrideWithValue('fake-uid'),
          birthdayRepositoryProvider.overrideWithValue(repository),
          shareServiceProvider.overrideWithValue(share),
          contactLinkRepositoryProvider.overrideWithValue(
            FakeContactLinkRepository(),
          ),
        ],
      );

  final bubble = find.byType(WishBubble);

  testWidgets('shows the message « Souhaiter » sends', (tester) async {
    await pumpActions(tester);

    expect(texts, hasLength(3));
    expect(
      find.descendant(of: bubble, matching: find.text(texts.first)),
      findsOneWidget,
    );

    await tester.tap(find.text('Souhaiter'));
    await tester.pump();

    expect(share.shared, [texts.first]);
    expect(repository.wished, [('lea', 2026)]);
  });

  testWidgets('opens the other messages; one tap shares the one touched', (
    tester,
  ) async {
    await pumpActions(tester);

    await tester.tap(bubble);
    await tester.pumpAndSettle();

    final sheet = find.byType(OtherWishesSheet);
    expect(find.text('Autres messages'), findsOneWidget);
    for (final text in texts) {
      expect(
        find.descendant(of: sheet, matching: find.text(text)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: sheet, matching: find.text(texts[2])));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(share.shared, [texts[2]]);
    expect(repository.wished, [('lea', 2026)]);
    expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);
  });

  testWidgets('still shares once the bubble is gone', (tester) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await pumpActions(tester, shown: shown);

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pump();
    expect(bubble, findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(OtherWishesSheet),
        matching: find.text(texts[2]),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(share.shared, [texts[2]]);
    expect(repository.wished, [('lea', 2026)]);
  });

  testWidgets('still opens their own message once the bubble is gone', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await pumpActions(tester, shown: shown);

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pump();
    await tester.tap(find.text('Écrire un message pour Léa'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Message'), findsOneWidget);
  });

  testWidgets('the bubble waits while a share sheet is open', (tester) async {
    final handle = tester.ensureSemantics();
    share.pending = Completer();
    await pumpActions(tester);

    await tester.tap(find.text('Souhaiter'));
    await tester.pump();
    await tester.tap(bubble);
    await tester.pumpAndSettle();

    expect(find.byType(OtherWishesSheet), findsNothing);
    expect(
      tester.getSemantics(find.byType(InkWell).first),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        label: texts.first,
        hint: 'Choisir un autre message',
      ),
    );

    share.pending!.complete(ShareOutcome.dismissed);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('each message of the sheet is a button that wishes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpActions(tester);

    await tester.tap(bubble);
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.descendant(
        of: find.byType(OtherWishesSheet),
        matching: find.text(texts[1]),
      ),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getSemantics(card),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: texts[1],
        hint: 'Souhaiter',
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('holds on a 360×640 phone at 130 %', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpActions(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sheet closed without a choice changes nothing', (
    tester,
  ) async {
    await pumpActions(tester);

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(find.byType(OtherWishesSheet), findsNothing);
    expect(share.shared, isEmpty);
    expect(repository.wished, isEmpty);
  });

  testWidgets('« Écrire un message » opens their own message', (tester) async {
    await pumpActions(tester);

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écrire un message pour Léa'));
    await tester.pumpAndSettle();

    expect(find.byType(OtherWishesSheet), findsNothing);
    expect(find.widgetWithText(TextField, 'Message'), findsOneWidget);
    expect(share.shared, isEmpty);
  });

  testWidgets('the bubble is a labelled 48 dp button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpActions(tester);

    expect(tester.getSize(bubble).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byType(InkWell).first),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: texts.first,
        hint: 'Choisir un autre message',
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('holds at 200 % text, sheet included', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpActions(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(bubble);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Écrire un message pour Léa'), findsOneWidget);
  });
}
