import 'dart:convert';

import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories);
  final List<BirthdayCategory> categories;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async => 'x';
}

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  final editable = BirthdayModel(
    id: 'edit-1',
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['fam'],
  );

  List<dynamic> overrides(
    RecordingBirthdayRepository repository, {
    UserModel? user,
  }) => [
    authProvider.overrideWith(
      () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
    ),
    birthdayRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(
      StubCategoryRepository([family]),
    ),
    userProfileProvider.overrideWithValue(
      AsyncData(
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
  ];

  testWidgets('create mode validates required fields', (tester) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();

      // Submit with empty fields: nothing is created and errors are shown.
      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();

      expect(repository.created, isEmpty);
      expect(find.text('Champ obligatoire'), findsWidgets);
    });
  });

  testWidgets('create mode submits with a selected category', (tester) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Bob');
      await tester.enterText(find.byType(TextField).at(1), 'Builder');

      // Toggle the "family" category chip.
      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();

      expect(repository.created, hasLength(1));
      expect(repository.created.single.name, 'Bob');
      expect(repository.created.single.categories, contains('fam'));
    });
  });

  testWidgets('edit mode pre-fills, shows the picture and updates', (
    tester,
  ) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable.copyWith(picture: _png)),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);

      // Deselect the pre-selected "family" category (covers the remove branch).
      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer').last);
      await tester.pumpAndSettle();

      expect(repository.updated, ['edit-1']);
      expect(repository.created.single.name, 'Alice');
    });
  });

  testWidgets('edit mode deletes after confirmation', (tester) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer l\'anniversaire'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(repository.deleted, contains('edit-1'));
    });
  });

  testWidgets('opens and closes the date picker', (tester) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(repository),
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
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(),
        overrides: overrides(repository),
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
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
    });
  });

  testWidgets('a failed save reaches the editor state', (tester) async {
    final repository = RecordingBirthdayRepository(
      failure: Exception('save failed'),
    );
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        BirthdayFormSheet(birthdayToEdit: editable),
        overrides: overrides(repository),
      );
      await tester.pumpAndSettle();
      // En vrai, l'écran d'accueil écoute l'éditeur et affiche l'erreur.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BirthdayFormSheet)),
      );
      container.listen(birthdayEditorProvider, (_, _) {});

      await tester.tap(find.text('Enregistrer').last);
      await tester.pumpAndSettle();

      expect(container.read(birthdayEditorProvider).hasError, isTrue);
    });
  });
}
