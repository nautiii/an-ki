import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _book = BirthdayCategory(
  id: 'book',
  name: 'Club de lecture',
  icon: 42,
  tone: 4,
);

Birthday _tagged(String id, List<String> categories) => Birthday(
  id: id,
  name: 'P$id',
  surname: '',
  date: const BirthDate(month: 1, day: 1),
  categories: categories,
);

void main() {
  late RecordingCategoryRepository categories;
  late RecordingBirthdayRepository birthdays;
  late RecordingUserRepository users;

  Future<ProviderContainer> makeContainer({String? uid = 'u'}) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        birthdayRepositoryProvider.overrideWithValue(birthdays),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container
      ..listen(categoryEditorProvider, (_, _) {})
      ..listen(birthdaysProvider, (_, _) {});
    await container.read(birthdaysProvider.future);
    return container;
  }

  setUp(() {
    categories = RecordingCategoryRepository(const [], own: const [_book]);
    birthdays = RecordingBirthdayRepository(
      initial: [
        _tagged('1', ['book', 'fam']),
        _tagged('2', ['fam']),
        _tagged('3', ['book', 'goat']),
      ],
    );
    users = RecordingUserRepository();
  });

  group('create', () {
    test('creates a private group and returns its id at once', () async {
      final container = await makeContainer();

      final id = container
          .read(categoryEditorProvider.notifier)
          .create(' Voisins ', icon: 42, tone: 4);

      expect(id, 'new-cat-1');
      await pumpEventQueue();
      expect(categories.created, [
        const BirthdayCategory(
          id: 'new-cat-1',
          name: 'Voisins',
          icon: 42,
          tone: 4,
        ),
      ]);
      expect(categories.createdFor, ['u']);
      expect(container.read(categoryEditorProvider), isA<AsyncData<void>>());
    });

    test('creates nothing without a session', () async {
      final container = await makeContainer(uid: null);

      final id = container
          .read(categoryEditorProvider.notifier)
          .create('Voisins', icon: 42, tone: 4);

      expect(id, isNull);
      await pumpEventQueue();
      expect(categories.created, isEmpty);
    });

    test('publishes a failed write as an AsyncError', () async {
      categories = RecordingCategoryRepository(
        const [],
        failure: Exception('permission-denied'),
      );
      final container = await makeContainer();

      container
          .read(categoryEditorProvider.notifier)
          .create('Voisins', icon: 42, tone: 4);
      await pumpEventQueue();

      expect(container.read(categoryEditorProvider).hasError, isTrue);
    });
  });

  group('edit', () {
    test('rewrites the group with a trimmed name', () async {
      final container = await makeContainer();

      container
          .read(categoryEditorProvider.notifier)
          .edit(
            const BirthdayCategory(
              id: 'book',
              name: ' Lecture ',
              icon: 42,
              tone: 9,
            ),
          );
      await pumpEventQueue();

      expect(categories.edited, [
        const BirthdayCategory(id: 'book', name: 'Lecture', icon: 42, tone: 9),
      ]);
    });

    test('edits nothing without a session', () async {
      final container = await makeContainer(uid: null);

      container.read(categoryEditorProvider.notifier).edit(_book);
      await pumpEventQueue();

      expect(categories.edited, isEmpty);
    });
  });

  group('remove', () {
    test('deletes an own group and drops it from its birthdays', () async {
      final container = await makeContainer();

      await container
          .read(categoryEditorProvider.notifier)
          .remove('book', GroupKind.own);

      expect(categories.deleted, ['book']);
      expect(users.removedCategories, isEmpty);
      expect(birthdays.removedCategories, {
        'book': ['1', '3'],
      });
      expect(container.read(categoryEditorProvider), isA<AsyncData<void>>());
    });

    test('a shared group leaves the profile and its birthdays', () async {
      final container = await makeContainer();

      await container
          .read(categoryEditorProvider.notifier)
          .remove('goat', GroupKind.shared);

      expect(categories.deleted, isEmpty);
      expect(users.removedCategories, ['goat']);
      expect(birthdays.removedCategories, {
        'goat': ['3'],
      });
    });

    test('touches no birthday when none carries the group', () async {
      final container = await makeContainer();

      await container
          .read(categoryEditorProvider.notifier)
          .remove('doggo', GroupKind.shared);

      expect(users.removedCategories, ['doggo']);
      expect(birthdays.removedCategories, isEmpty);
    });

    test('leaves a preset alone, and everything without a session', () async {
      var container = await makeContainer();
      await container
          .read(categoryEditorProvider.notifier)
          .remove('fam', GroupKind.preset);
      container = await makeContainer(uid: null);
      await container
          .read(categoryEditorProvider.notifier)
          .remove('book', GroupKind.own);

      expect(categories.deleted, isEmpty);
      expect(users.removedCategories, isEmpty);
      expect(birthdays.removedCategories, isEmpty);
    });

    test('publishes a failed removal as an AsyncError', () async {
      birthdays = RecordingBirthdayRepository(
        initial: [
          _tagged('1', ['book']),
        ],
        failure: Exception('unavailable'),
      );
      final container = await makeContainer();

      await container
          .read(categoryEditorProvider.notifier)
          .remove('book', GroupKind.own);

      expect(container.read(categoryEditorProvider).hasError, isTrue);
    });
  });
}
