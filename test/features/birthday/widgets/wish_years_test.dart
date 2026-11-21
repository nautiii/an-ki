import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/wish_years.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le 12 octobre 2026 : l'anniversaire de Léa (24 octobre) en cours est
  // celui de 2025.
  final today = DateTime(2026, 10, 12);

  Birthday lea(List<int> wishedYears) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: const BirthDate(year: 1990, month: 10, day: 24),
    wishedYears: wishedYears,
  );

  late RecordingBirthdayRepository repository;

  Future<void> pump(WidgetTester tester, Birthday person) async {
    repository = RecordingBirthdayRepository();
    await tester.pumpHarness(
      Scaffold(
        body: WishYears(birthday: person, today: today),
      ),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdayRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  testWidgets('nothing when never wished', (tester) async {
    await pump(tester, lea(const []));

    expect(find.text('Vœux'), findsNothing);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('the years, the latest first, read as sentences', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, lea(const [2022, 2025, 2024]));

    final years = tester
        .widgetList<Chip>(find.byType(Chip))
        .map((chip) => (chip.label as Text).data);
    expect(years, ['2025', '2024', '2022']);
    expect(find.bySemanticsLabel('Souhaité en 2024'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Vœux')),
      isSemantics(label: 'Vœux', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('only the birthday in progress can be removed', (tester) async {
    await pump(tester, lea(const [2024, 2025]));

    expect(find.byTooltip('Retirer le vœu de 2025'), findsOneWidget);
    expect(find.byTooltip('Retirer le vœu de 2024'), findsNothing);
  });

  testWidgets('removes it, with a way back', (tester) async {
    await pump(tester, lea(const [2025]));

    await tester.tap(find.byTooltip('Retirer le vœu de 2025'));
    await tester.pumpAndSettle();

    expect(repository.unwished, [('lea', 2025)]);
    expect(find.text('Vœu de 2025 retiré'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(repository.wished, [('lea', 2025)]);
  });

  testWidgets('leaves twice as long to undo with TalkBack', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, lea(const [2025]));

    await tester.tap(find.byTooltip('Retirer le vœu de 2025'));
    await tester.pump();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      undoDelay * 2,
    );
  });

  testWidgets('48 dp targets, labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, lea(const [2025, 2024]));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
