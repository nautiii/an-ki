import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
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

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
    haptics = [];
  });

  /// Les actions de [birthday] au jour [today] ; les vibrations demandées
  /// sont relevées dans [haptics].
  Future<void> pumpActions(
    WidgetTester tester, {
    required DateTime today,
    Birthday birthday = lea,
    bool wished = false,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpHarness(
      WishActions(birthday: birthday, wished: wished, onColor: Colors.white),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdayRepositoryProvider.overrideWithValue(repository),
        shareServiceProvider.overrideWithValue(share),
      ],
    );
  }

  group('Souhaiter', () {
    testWidgets('shares a ready message and marks the wish', (tester) async {
      await pumpActions(tester, today: DateTime(2026, 12, 31));

      await tester.tap(find.text('Souhaiter'));
      await tester.pump();

      expect(share.shared, [
        'Joyeux anniversaire Léa ! 🎂 Je te souhaite une très belle '
            'journée.',
      ]);
      expect(repository.wished, [('lea', 2026)]);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);
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

  testWidgets('shows the wished pill at the height of a button', (
    tester,
  ) async {
    await pumpActions(tester, today: DateTime(2026, 12, 31), wished: true);

    expect(find.text('Souhaité'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    final pill = find
        .ancestor(
          of: find.text('Souhaité'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(
      tester.getSize(pill).height,
      greaterThanOrEqualTo(kMinInteractiveDimension),
    );
  });
}
