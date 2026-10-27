import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/belated_wish.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le 1er janvier 2027 : le 31 décembre est d'hier, sur l'année 2026.
  final today = DateTime(2027);

  Birthday bornOn(
    int month,
    int day, {
    String id = 'nina',
    String name = 'Nina',
    String surname = 'Rossi',
    List<int> wishedYears = const [],
  }) => Birthday(
    id: id,
    name: name,
    surname: surname,
    date: BirthDate(year: 1995, month: month, day: day),
    wishedYears: wishedYears,
  );

  late RecordingBirthdayRepository repository;
  late FakeShareService share;

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
  });

  /// Les rappels d'hier sur la largeur utile d'un téléphone de 360 dp, ou
  /// sur celle que suit [width] quand elle est donnée ; [theme] remplace le
  /// thème du harnais.
  Future<void> pumpBelated(
    WidgetTester tester,
    List<Birthday> birthdays, {
    double width = 312,
    ValueNotifier<double>? widthNotifier,
    ThemeData? theme,
  }) => mockNetworkImages(() async {
    Widget card = const BelatedWishes();
    if (theme != null) card = Theme(data: theme, child: card);
    await tester.pumpHarness(
      Center(
        child: ValueListenableBuilder(
          valueListenable: widthNotifier ?? ValueNotifier(width),
          builder: (context, value, child) =>
              SizedBox(width: value, child: child),
          child: card,
        ),
      ),
      overrides: [
        birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
        birthdayRepositoryProvider.overrideWithValue(repository),
        shareServiceProvider.overrideWithValue(share),
      ],
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows nothing without a birthday yesterday', (tester) async {
    await pumpBelated(tester, [bornOn(1, 1), bornOn(12, 30, id: 'other')]);

    expect(find.byType(Card), findsNothing);
    expect(find.text('Hier'), findsNothing);
  });

  testWidgets('shows nothing once yesterday was wished', (tester) async {
    await pumpBelated(tester, [
      bornOn(12, 31, wishedYears: const [2026]),
    ]);

    expect(find.text('Hier'), findsNothing);
  });

  testWidgets('recalls yesterday, a card per person', (tester) async {
    await pumpBelated(tester, [
      bornOn(12, 31),
      bornOn(12, 31, id: 'ada', name: 'Ada'),
    ]);

    expect(find.text('Hier'), findsNWidgets(2));
    expect(find.text('Ada Rossi'), findsOneWidget);
    expect(find.text('Nina Rossi'), findsOneWidget);
    // Par nom.
    expect(
      tester.getTopLeft(find.text('Ada Rossi')).dy,
      lessThan(tester.getTopLeft(find.text('Nina Rossi')).dy),
    );
  });

  testWidgets('wishes late, for the year of yesterday', (tester) async {
    await pumpBelated(tester, [bornOn(12, 31)]);

    await tester.tap(find.text('Souhaiter'));
    await tester.pump();

    expect(share.shared, [
      'Joyeux anniversaire avec un jour de retard, Nina ! 🎂 '
          "J'espère que tu as passé une très belle journée.",
    ]);
    expect(repository.wished, [('nina', 2026)]);
    expect(find.text('Nina Rossi a reçu vos vœux'), findsOneWidget);
  });

  testWidgets('marks yesterday wished, and undoes it', (tester) async {
    await pumpBelated(tester, [bornOn(12, 31)]);

    await tester.tap(find.byTooltip('Déjà souhaité'));
    await tester.pump();

    expect(repository.wished, [('nina', 2026)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pump();

    expect(repository.unwished, [('nina', 2026)]);
  });

  testWidgets('tapping the person opens the edit sheet', (tester) async {
    await pumpBelated(tester, [bornOn(12, 31)]);

    await tester.tap(find.text('Nina Rossi'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
  });

  testWidgets('reads the person as one button, the actions apart', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpBelated(tester, [bornOn(12, 31)]);

    expect(
      tester.getSemantics(find.text('Nina Rossi')),
      isSemantics(
        label: 'Hier\nNina Rossi',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.byTooltip('Déjà souhaité'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('keeps the actions beside the name when it has room', (
    tester,
  ) async {
    await pumpBelated(tester, [bornOn(12, 31)], width: 600);

    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.text('Souhaiter')).dy,
      closeTo(tester.getCenter(find.text('Nina Rossi')).dy, 24),
    );
    expect(
      tester.getTopLeft(find.text('Souhaiter')).dx,
      greaterThan(tester.getTopRight(find.text('Nina Rossi')).dx),
    );
  });

  testWidgets('puts the actions under a name left without room', (
    tester,
  ) async {
    await pumpBelated(tester, [bornOn(12, 31)], width: 240);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Souhaiter')).dy,
      greaterThan(tester.getBottomLeft(find.text('Nina Rossi')).dy),
    );
  });

  testWidgets('never cuts the name beside the actions, with the app theme', (
    tester,
  ) async {
    const name = 'Nina Rossi-Delacroix de Montmorency';
    final width = ValueNotifier(260.0);
    addTearDown(width.dispose);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpBelated(
      tester,
      [bornOn(12, 31, surname: 'Rossi-Delacroix de Montmorency')],
      widthNotifier: width,
      theme: AppTheme.light,
    );

    // Le thème impose ses marges au bouton : la mesure doit suivre les
    // siennes, à chaque largeur où les actions restent à côté du nom.
    var rows = 0;
    for (final scale in [1.0, 1.3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      for (var value = 260.0; value <= 720; value += 4) {
        width.value = value;
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Empilé, le nom a toute la largeur : seule la ligne compte ici.
        final beside =
            tester.getTopLeft(find.text('Souhaiter')).dy <
            tester.getBottomLeft(find.text(name)).dy;
        if (!beside) continue;
        rows++;
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(name))
              .didExceedMaxLines,
          isFalse,
          reason: 'à $value dp, texte à $scale',
        );
      }
    }
    // Les deux dispositions ont bien été parcourues.
    expect(rows, greaterThan(0));
  });

  testWidgets('opens one share sheet at a time', (tester) async {
    share.pending = Completer();
    await pumpBelated(tester, [bornOn(12, 31)]);

    await tester.tap(find.text('Souhaiter'));
    await tester.pump();

    final button = find.ancestor(
      of: find.text('Souhaiter'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

    share.pending!.complete(ShareOutcome.dismissed);
    await tester.pump();

    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
  });

  testWidgets('puts the actions under the name at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpBelated(tester, [bornOn(12, 31)]);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Souhaiter')).dy,
      greaterThan(tester.getBottomLeft(find.text('Nina Rossi')).dy),
    );
  });
}
