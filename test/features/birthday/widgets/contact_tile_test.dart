import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  Birthday birthday({Uint8List? picture}) => Birthday(
    id: '1',
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['fam'],
    picture: picture,
  );

  List<dynamic> overrides({bool failCategories = false}) => [
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(
      const AsyncData(
        UserProfile(
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
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository([
        family,
      ], watchError: failCategories ? Exception('boom') : null),
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

  testWidgets('shows initials, date and age without a picture', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        ContactTile(birthday: birthday()),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('AW'), findsOneWidget);
      expect(find.text('10 mai 1990'), findsOneWidget);
      expect(find.text('ans'), findsOneWidget);
    });
  });

  testWidgets('reads as one button that also offers deletion', (tester) async {
    final semantics = tester.ensureSemantics();
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        ContactTile(birthday: birthday()),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Alice Wonderland')),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          customActions: [const CustomSemanticsAction(label: 'Supprimer')],
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
    semantics.dispose();
  });

  testWidgets('keeps everything whole at 200 % text on a small phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await tester.pumpHarness(
        Center(
          child: SizedBox(width: 312, child: ContactTile(birthday: birthday())),
        ),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Famille'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
