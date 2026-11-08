import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/widgets/wish_message_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le message par défaut, l'espace avant « ! » insécable.
  const fallback = 'Bon anniversaire Léa ! 🎂';

  Birthday lea({String? wishMessage}) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: const BirthDate(month: 10, day: 24),
    wishMessage: wishMessage,
  );

  late RecordingBirthdayRepository repository;

  setUp(() => repository = RecordingBirthdayRepository());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpHarness(
      Scaffold(body: child),
      overrides: [
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdayRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
  }

  final field = find.widgetWithText(TextField, 'Message');

  bool saveEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.ancestor(
          of: find.text('Enregistrer'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      )
      .enabled;

  group('section', () {
    testWidgets('shows the default message, said so', (tester) async {
      await pump(tester, WishMessageSection(birthday: lea()));

      expect(find.text('Message de vœux'), findsOneWidget);
      expect(find.text(fallback), findsOneWidget);
      expect(find.text('Message par défaut'), findsOneWidget);
    });

    testWidgets('shows their own message', (tester) async {
      await pump(tester, WishMessageSection(birthday: lea(wishMessage: 'Yo')));

      expect(find.text('Yo'), findsOneWidget);
      expect(find.text('Message par défaut'), findsNothing);
    });

    testWidgets('is a 48 dp button that opens the sheet', (tester) async {
      await pump(tester, WishMessageSection(birthday: lea()));

      final row = find.byType(InkWell);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          label: '$fallback\nMessage par défaut',
          hint: 'Modifier le message de vœux',
        ),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(field, findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('starts from the default, nothing to save yet', (tester) async {
      await pump(tester, WishMessageSheet(birthday: lea()));

      expect(tester.widget<TextField>(field).controller?.text, fallback);
      expect(saveEnabled(tester), isFalse);
      expect(find.text('Rétablir le message par défaut'), findsNothing);
    });

    testWidgets('saves an own message, trimmed', (tester) async {
      await pump(tester, WishMessageSheet(birthday: lea()));

      await tester.enterText(field, '  Joyeux anniversaire ma sœur !  ');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.wishMessageUpdates, [
        ('lea', 'Joyeux anniversaire ma sœur !'),
      ]);
    });

    testWidgets('an emptied message goes back to the default', (tester) async {
      await pump(tester, WishMessageSheet(birthday: lea(wishMessage: 'Yo')));

      await tester.enterText(field, '');
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.wishMessageUpdates, [('lea', null)]);
    });

    testWidgets('restores the default message, with a way back', (
      tester,
    ) async {
      await pump(tester, WishMessageSheet(birthday: lea(wishMessage: 'Yo')));

      expect(tester.widget<TextField>(field).controller?.text, 'Yo');
      expect(saveEnabled(tester), isFalse);
      await tester.tap(find.text('Rétablir le message par défaut'));
      await tester.pumpAndSettle();

      expect(repository.wishMessageUpdates, [('lea', null)]);
      expect(find.text('Message par défaut rétabli'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(repository.wishMessageUpdates, [('lea', null), ('lea', 'Yo')]);
    });

    testWidgets('nothing to save when only the spaces of the default change', (
      tester,
    ) async {
      await pump(tester, WishMessageSheet(birthday: lea()));

      await tester.enterText(field, '  Bon anniversaire Léa ! 🎂 ');
      await tester.pump();

      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('caps the message at 500 characters', (tester) async {
      await pump(tester, WishMessageSheet(birthday: lea()));

      expect(tester.widget<TextField>(field).maxLength, 500);
    });
  });
}
