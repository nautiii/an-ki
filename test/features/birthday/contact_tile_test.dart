import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories, {this.fail = false});
  final List<BirthdayCategory> categories;
  final bool fail;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => fail
      ? Stream.fromFuture(
          Future<List<BirthdayCategory>>.error(Exception('boom')),
        )
      : Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async => 'x';
}

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  BirthdayModel birthday({Uint8List? picture}) => BirthdayModel(
    id: '1',
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['fam'],
    picture: picture,
  );

  List<dynamic> overrides({bool failCategories = false}) => [
    authProvider.overrideWith(
      () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
    ),
    userProfileProvider.overrideWithValue(
      const AsyncData(
        UserModel(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          categories: ['fam'],
          isDark: false,
          locale: 'fr',
        ),
      ),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
    categoryRepositoryProvider.overrideWithValue(
      StubCategoryRepository([family], fail: failCategories),
    ),
  ];

  testWidgets('shows the picture, category chip and opens the edit sheet', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        ContactTile(birthday: birthday(picture: _png)),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Famille'), findsOneWidget);

      await tester.tap(find.text('Alice Wonderland'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
    });
  });

  testWidgets('tolerates a category stream error', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        ContactTile(birthday: birthday()),
        overrides: overrides(failCategories: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
    });
  });
}
