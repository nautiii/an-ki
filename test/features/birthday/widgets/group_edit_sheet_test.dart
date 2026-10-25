import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/group_edit_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
const _book = BirthdayCategory(
  id: 'book',
  name: 'Club de lecture',
  icon: 42,
  tone: 4,
);

void main() {
  late RecordingCategoryRepository categories;

  setUp(
    () => categories = RecordingCategoryRepository([_family], own: [_book]),
  );

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpHarness(
      const Scaffold(body: GroupEditSheet(group: _book)),
      overrides: [
        currentUidProvider.overrideWithValue('fake-uid'),
        categoryRepositoryProvider.overrideWithValue(categories),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserProfile(id: 'fake-uid', name: 'A', surname: 'B', locale: 'fr'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  final nameField = find.widgetWithText(TextField, 'Nom du groupe');

  bool saveEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.ancestor(
          of: find.text('Enregistrer'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      )
      .enabled;

  testWidgets('saves a new name, the tone kept', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Modifier le groupe'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(nameField, 'Lecture');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(categories.edited, [
      const BirthdayCategory(id: 'book', name: 'Lecture', icon: 42, tone: 4),
    ]);
  });

  testWidgets('saves a new tone', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.bySemanticsLabel('Ambre'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(categories.edited.single.tone, 7);
    expect(categories.edited.single.name, 'Club de lecture');
  });

  testWidgets('refuses a name another group has', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(nameField, ' famille ');
    await tester.pump();

    expect(find.text('Ce groupe existe déjà'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(nameField, '  ');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
  });
}
