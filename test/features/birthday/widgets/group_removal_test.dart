import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/screens/groups_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
const _goat = BirthdayCategory(id: 'goat', name: 'goat', icon: 1);
const _book = BirthdayCategory(
  id: 'book',
  name: 'Club de lecture',
  icon: 42,
  tone: 4,
);

const _profile = UserProfile(
  id: 'fake-uid',
  name: 'A',
  surname: 'B',
  categories: ['goat'],
  locale: 'fr',
);

void main() {
  late RecordingCategoryRepository categories;
  late RecordingBirthdayRepository birthdays;
  late RecordingUserRepository users;

  setUp(() {
    categories = RecordingCategoryRepository([_family, _goat], own: [_book]);
    birthdays = RecordingBirthdayRepository(
      initial: const [
        Birthday(
          id: 'lea',
          name: 'Léa',
          surname: '',
          date: BirthDate(month: 3, day: 12),
          categories: ['book', 'goat'],
        ),
      ],
    );
    users = RecordingUserRepository(stored: _profile);
  });

  Future<void> pumpGroups(WidgetTester tester) async {
    await tester.pumpHarness(
      const GroupsScreen(),
      overrides: [
        currentUidProvider.overrideWithValue('fake-uid'),
        categoryRepositoryProvider.overrideWithValue(categories),
        birthdayRepositoryProvider.overrideWithValue(birthdays),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAndTap(
    WidgetTester tester,
    String group,
    String action,
  ) async {
    await tester.tap(find.text(group));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('deletes an own group once « Annuler » is gone', (tester) async {
    await pumpGroups(tester);

    await openAndTap(tester, 'Club de lecture', 'Supprimer le groupe');

    expect(find.text('Club de lecture'), findsNothing);
    expect(find.text('« Club de lecture » est supprimé'), findsOne);
    expect(categories.deleted, isEmpty);

    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(categories.deleted, ['book']);
    expect(birthdays.removedCategories, {
      'book': ['lea'],
    });
  });

  testWidgets('« Annuler » brings the group back, untouched', (tester) async {
    await pumpGroups(tester);

    await openAndTap(tester, 'Club de lecture', 'Supprimer le groupe');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Club de lecture'), findsOneWidget);
    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(categories.deleted, isEmpty);
    expect(birthdays.removedCategories, isEmpty);
  });

  testWidgets('a shared group leaves the profile and the birthdays', (
    tester,
  ) async {
    await pumpGroups(tester);

    await openAndTap(tester, 'GOAT', 'Retirer de mes groupes');

    expect(find.text('GOAT'), findsNothing);
    expect(find.text('« GOAT » n\'est plus dans vos groupes'), findsOne);

    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(users.removedCategories, ['goat']);
    expect(categories.deleted, isEmpty);
    expect(birthdays.removedCategories, {
      'goat': ['lea'],
    });
  });
}
