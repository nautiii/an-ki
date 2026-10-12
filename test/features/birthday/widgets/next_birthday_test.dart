import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  final today = DateTime(2026, 3, 12);

  Birthday relative(
    int daysAhead, {
    String id = '1',
    String name = 'Alice',
    String surname = 'Wonderland',
    Uint8List? picture,
  }) {
    final target = today.add(Duration(days: daysAhead));
    return Birthday(
      id: id,
      name: name,
      surname: surname,
      date: DateTime(1990, target.month, target.day),
      picture: picture,
    );
  }

  /// La carte sur la largeur utile d'un téléphone de 360 dp (marges ôtées).
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<Birthday> birthdays,
    bool isLoading = false,
  }) async {
    await tester.pumpHarness(
      const Center(child: SizedBox(width: 312, child: NextBirthdayCard())),
      overrides: [
        birthdaysProvider.overrideWithValue(
          isLoading ? const AsyncLoading() : AsyncData(birthdays),
        ),
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
      ],
    );
  }

  testWidgets('shows nothing when there is no birthday', (tester) async {
    await pumpCard(tester, birthdays: const []);
    await tester.pumpAndSettle();

    expect(find.text('Prochain anniversaire'), findsNothing);
    expect(find.byType(SkeletonBox), findsNothing);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    await pumpCard(tester, birthdays: const [], isLoading: true);
    await tester.pump();

    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows who, when and how old', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      expect(find.text('Prochain anniversaire'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('AW'), findsOneWidget);
      expect(find.text('Dans 3 jours'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);
      // L'âge atteint au prochain anniversaire, annoncé par « aura ».
      expect(find.text('aura'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('ans'), findsOneWidget);
    });
  });

  testWidgets('labels a birthday happening today', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0, picture: _png)]);
      await tester.pumpAndSettle();

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('aura'), findsNothing);
    });
  });

  testWidgets('labels a birthday happening tomorrow', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(1)]);
      await tester.pumpAndSettle();

      expect(find.text('Demain'), findsOneWidget);
    });
  });

  testWidgets('stacks every same-day birthday', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          relative(2),
          relative(2, id: '2', name: 'Bob', surname: 'Builder'),
          relative(9, id: '3', name: 'Carl', surname: 'Later'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text('Carl Later'), findsNothing);
    });
  });

  testWidgets('tapping the card opens the edit sheet', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice Wonderland'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
    });
  });

  testWidgets('reads as a single button for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Alice Wonderland')),
        isSemantics(
          label:
              'Prochain anniversaire\nAlice Wonderland\nDans 3 jours\n'
              '15 mars\naura\n36\nans',
          isButton: true,
          hasTapAction: true,
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
      await pumpCard(tester, birthdays: [relative(12)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Dans 12 jours'), findsOneWidget);
      expect(find.text('24 mars'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
