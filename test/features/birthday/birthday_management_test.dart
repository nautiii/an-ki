import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

/// A birthday whose anniversary is [daysAhead] days from today.
Birthday _relative(
  int daysAhead, {
  required String id,
  required String name,
  required String surname,
}) {
  final today = DateTime.now();
  final target = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysAhead));
  return Birthday(
    id: id,
    name: name,
    surname: surname,
    date: DateTime(1990, target.month, target.day),
  );
}

void main() {
  // The closest birthday is rendered in the "next birthday" card and excluded
  // from the scrollable list, so we always provide a second, farther one.
  final next = _relative(5, id: 'next', name: 'Alice', surname: 'Wonderland');
  final listed = _relative(40, id: 'listed', name: 'Bob', surname: 'Builder');

  List<dynamic> overridesWith(RecordingBirthdayRepository repository) => [
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(const AsyncData(null)),
    birthdayRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
  ];

  testWidgets('HomeScreen lists non-next birthdays', (tester) async {
    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overridesWith(
        RecordingBirthdayRepository(initial: [next, listed]),
      ),
    );
    await tester.pumpAndSettle();

    // "Alice" appears in the next-birthday card, "Bob" in the list below.
    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(find.text('Bob Builder'), findsOneWidget);
  });

  testWidgets('swiping a listed birthday asks for confirmation and deletes it', (
    tester,
  ) async {
    final repository = RecordingBirthdayRepository(initial: [next, listed]);

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overridesWith(repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob Builder'), findsOneWidget);

    // Swipe the listed tile (start-to-end) to trigger the delete confirmation.
    await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer l\'anniversaire'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(repository.deleted, contains('listed'));
  });

  testWidgets('a failed delete is announced once the tile is gone', (
    tester,
  ) async {
    final repository = RecordingBirthdayRepository(
      initial: [next, listed],
      failure: Exception('denied'),
    );

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overridesWith(repository),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text("Erreur lors de l'enregistrement de l'anniversaire"),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the confirmation keeps the birthday', (tester) async {
    final repository = RecordingBirthdayRepository(initial: [next, listed]);

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: overridesWith(repository),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isEmpty);
    expect(find.text('Bob Builder'), findsOneWidget);
  });
}
