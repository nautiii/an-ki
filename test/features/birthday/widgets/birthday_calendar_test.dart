import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  // Octobre 2026 commence un jeudi.
  final today = DateTime(2026, 10, 11);
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  Birthday born(
    DateTime date, {
    String id = '1',
    String name = 'Alice',
    Uint8List? picture,
  }) => Birthday(
    id: id,
    name: name,
    surname: 'Wonderland',
    date: BirthDate.fromDate(date),
    categories: const ['fam'],
    picture: picture,
  );

  Birthday onDay(int day, {String id = '1', String name = 'Alice'}) =>
      born(DateTime(1990, today.month, day), id: id, name: name);

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<Birthday> birthdays,
    DateTime? on,
  }) async {
    await tester.pumpHarness(
      const SingleChildScrollView(child: BirthdayCalendar()),
      overrides: [
        birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
        clockProvider.overrideWithValue(() => on ?? today),
        currentUidProvider.overrideWithValue('u1'),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([family]),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('titles the month and navigates between months', (tester) async {
    await pumpCalendar(tester, birthdays: [onDay(15)]);

    expect(find.text('Octobre 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Mois suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Mois précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget);
  });

  testWidgets('starts the week on Monday and places the 1st on its weekday', (
    tester,
  ) async {
    await pumpCalendar(tester, birthdays: const []);

    final weekdays = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ExcludeSemantics),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();
    expect(weekdays, ['L', 'M', 'M', 'J', 'V', 'S', 'D']);

    // Le jeudi 1er octobre sous le « J », le lundi 5 sous le « L ».
    expect(
      tester.getCenter(find.text('1')).dx,
      moreOrLessEquals(tester.getCenter(find.text('J')).dx, epsilon: 0.5),
    );
    expect(
      tester.getCenter(find.text('5')).dx,
      moreOrLessEquals(tester.getCenter(find.text('L')).dx, epsilon: 0.5),
    );
  });

  testWidgets('announces each day with its date and who is celebrated', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(tester, birthdays: [onDay(15)]);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('jeudi 15 octobre, Alice Wonderland'),
      ),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('vendredi 16 octobre'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('shows a 29 February birthday on 1 March in common years', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(
      tester,
      birthdays: [born(DateTime(2000, 2, 29), name: 'Leap')],
      on: DateTime(2027, 3, 10),
    );

    expect(
      find.bySemanticsLabel('lundi 1 mars, Leap Wonderland'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('tapping a day with birthdays opens the detail sheet', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCalendar(
        tester,
        birthdays: [born(DateTime(1990, 10, 15), picture: _png)],
      );

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.text('15 octobre 2026'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      // Âge actuel (35), comme ailleurs dans l'app : « aura 36 ans » viendra avec B1.
      expect(find.text('35 ans'), findsOneWidget);
    });
  });

  testWidgets('day sheet lists multiple birthdays with a separator', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCalendar(
        tester,
        birthdays: [
          onDay(15),
          onDay(15, id: '2', name: 'Bob'),
        ],
      );

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Wonderland'), findsOneWidget);
    });
  });

  testWidgets('keeps the header whole at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpCalendar(tester, birthdays: [onDay(15)]);

    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps 48 dp cells on a 360 dp phone', (tester) async {
    final semantics = tester.ensureSemantics();
    // 360 dp moins les marges de 12 dp de l'accueil.
    await tester.pumpHarness(
      const Center(
        child: SizedBox(
          width: 336,
          child: SingleChildScrollView(child: BirthdayCalendar()),
        ),
      ),
      overrides: [
        birthdaysProvider.overrideWithValue(AsyncData([onDay(15)])),
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('u1'),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([family]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final cell = tester.getSize(
      find.bySemanticsLabel(RegExp('jeudi 15 octobre')),
    );
    expect(cell.width, greaterThanOrEqualTo(48));
    expect(cell.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a tap in the cell margin still opens the day', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(tester, birthdays: [onDay(15)]);

    // La case entière (nœud sémantique) ; son coin est dans le retrait, hors
    // de la case dessinée.
    final cell = tester.getRect(
      find.bySemanticsLabel(RegExp('jeudi 15 octobre')),
    );
    await tester.tapAt(cell.topLeft + const Offset(1, 1));
    await tester.pumpAndSettle();

    expect(find.text('Alice Wonderland'), findsOneWidget);
    semantics.dispose();
  });
}
