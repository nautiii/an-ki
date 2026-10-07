import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories);
  final List<BirthdayCategory> categories;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async => 'x';
}

class _ThrowingBirthdayNotifier extends FakeBirthdayNotifier {
  @override
  Future<void> updateBirthday(String uid, String id, input) async =>
      throw Exception('save failed');
}

void main() {
  final family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  final editable = BirthdayModel(
    id: 'edit-1',
    uid: 'fake-uid',
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['fam'],
  );

  List<dynamic> overrides(FakeBirthdayNotifier notifier, {UserModel? user}) => [
    authProvider.overrideWith(
      () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
    ),
    birthdayProvider.overrideWith(() => notifier),
    categoryRepositoryProvider.overrideWithValue(
      StubCategoryRepository([family]),
    ),
    userProvider.overrideWith(
      () => FakeUserNotifier(
        initialState: UserState(
          user:
              user ??
              const UserModel(
                id: 'fake-uid',
                name: 'A',
                surname: 'B',
                categories: ['fam'],
                isDark: false,
                locale: 'fr',
              ),
        ),
      ),
    ),
  ];

  testWidgets('create mode validates required fields', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      // Submit with empty fields: nothing is created and errors are shown.
      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();

      expect(notifier.createdInputs, isEmpty);
      expect(find.text('Champ obligatoire'), findsWidgets);
    });
  });

  testWidgets('create mode submits with a selected category', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Bob');
      await tester.enterText(find.byType(TextField).at(1), 'Builder');

      // Toggle the "family" category chip.
      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();

      expect(notifier.createdInputs, hasLength(1));
      expect(notifier.createdInputs.single.name, 'Bob');
      expect(notifier.createdInputs.single.categories, contains('fam'));
    });
  });

  testWidgets('edit mode pre-fills, shows the picture and updates', (
    tester,
  ) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(
          birthdayToEdit: editable.copyWith(picture: _pngBase64),
        ),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);

      // Deselect the pre-selected "family" category (covers the remove branch).
      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer').last);
      await tester.pumpAndSettle();

      expect(notifier.createdInputs, hasLength(1));
      expect(notifier.createdInputs.single.name, 'Alice');
    });
  });

  testWidgets('edit mode tolerates an invalid picture', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(
          birthdayToEdit: editable.copyWith(picture: '!!notbase64!!'),
        ),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
    });
  });

  testWidgets('edit mode deletes after confirmation', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer l\'anniversaire'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(notifier.deletedIds, contains('edit-1'));
    });
  });

  testWidgets('opens and closes the date picker', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
    });
  });

  testWidgets('close button is wired', (tester) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('cancelling the delete dialog keeps the birthday', (
    tester,
  ) async {
    final notifier = FakeBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(notifier.deletedIds, isEmpty);
    });
  });

  testWidgets('shows a SnackBar when saving fails', (tester) async {
    final notifier = _ThrowingBirthdayNotifier();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer').last);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  testWidgets('disables the actions while creating', (tester) async {
    final notifier = FakeBirthdayNotifier(
      initialState: BirthdayState(isCreating: true, isLoading: false),
    );
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(notifier),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
