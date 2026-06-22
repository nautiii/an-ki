import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';

class _FakeContactsService extends ContactsService {
  const _FakeContactsService({this.granted = true, this.contacts = const []});

  final bool granted;
  final List<ImportedBirthday> contacts;

  @override
  Future<bool> requestReadPermission() async => granted;

  @override
  Future<List<ImportedBirthday>> fetchBirthdays() async => contacts;
}

/// Builds a birthday whose anniversary falls [daysAhead] days from today,
/// keeping it independent from the current date.
BirthdayModel _relative(
  int daysAhead, {
  required String id,
  required String name,
  required String surname,
  List<String> categories = const [],
}) {
  final today = DateTime.now();
  final target = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysAhead));
  return BirthdayModel(
    id: id,
    uid: 'u',
    name: name,
    surname: surname,
    date: DateTime(1990, target.month, target.day),
    categories: categories,
  );
}

class RecordingBirthdayRepository extends FakeBirthdayRepository {
  RecordingBirthdayRepository({this.initial = const []});

  final List<BirthdayModel> initial;
  final List<CreateBirthdayInput> created = [];
  final List<String> updated = [];
  final List<String> deleted = [];

  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) =>
      Stream.value(initial);

  @override
  Future<void> createBirthday(String uid, CreateBirthdayInput input) async =>
      created.add(input);

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async => updated.add(birthdayId);

  @override
  Future<void> deleteBirthday(String uid, String birthdayId) async =>
      deleted.add(birthdayId);
}

class _ErroringBirthdayRepository extends FakeBirthdayRepository {
  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) =>
      Stream.error(Exception('stream failed'));
}

CreateBirthdayInput _input() => CreateBirthdayInput(
  uid: 'u',
  name: 'New',
  surname: 'Person',
  date: DateTime(2000),
  categories: const [],
);

void main() {
  group('BirthdayNotifier (real)', () {
    test('initial state is loading', () {
      final container = ProviderContainer(
        overrides: [
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(birthdayProvider).isLoading, true);
    });

    test('startListening publishes data and clears the loading flag', () async {
      final repo = RecordingBirthdayRepository(
        initial: [_relative(5, id: '1', name: 'A', surname: 'B')],
      );
      final container = ProviderContainer(
        overrides: [birthdayRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(birthdayProvider.notifier).startListening('u');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(birthdayProvider);
      expect(state.isLoading, false);
      expect(state.birthdays, hasLength(1));
    });

    test('startListening clears loading on a stream error', () async {
      final container = ProviderContainer(
        overrides: [
          birthdayRepositoryProvider.overrideWithValue(
            _ErroringBirthdayRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(birthdayProvider.notifier).startListening('u');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(birthdayProvider).isLoading, false);
    });

    test(
      'createBirthday forwards to the repository and toggles isCreating',
      () async {
        final repo = RecordingBirthdayRepository();
        final container = ProviderContainer(
          overrides: [birthdayRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(birthdayProvider.notifier);

        await notifier.createBirthday('u', _input());

        expect(repo.created, hasLength(1));
        expect(container.read(birthdayProvider).isCreating, false);
      },
    );

    test('createBirthday ignores re-entrancy while already creating', () async {
      final repo = RecordingBirthdayRepository();
      final container = ProviderContainer(
        overrides: [birthdayRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(birthdayProvider.notifier);

      // Fire two creations without awaiting the first: the second is rejected.
      final first = notifier.createBirthday('u', _input());
      final second = notifier.createBirthday('u', _input());
      await Future.wait([first, second]);

      expect(repo.created, hasLength(1));
    });

    test(
      'updateBirthday and deleteBirthday forward to the repository',
      () async {
        final repo = RecordingBirthdayRepository();
        final container = ProviderContainer(
          overrides: [birthdayRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(birthdayProvider.notifier);

        await notifier.updateBirthday('u', 'id-1', _input());
        await notifier.deleteBirthday('u', 'id-2');

        expect(repo.updated, ['id-1']);
        expect(repo.deleted, ['id-2']);
      },
    );

    test('clear resets the state', () async {
      final repo = RecordingBirthdayRepository(
        initial: [_relative(5, id: '1', name: 'A', surname: 'B')],
      );
      final container = ProviderContainer(
        overrides: [birthdayRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(birthdayProvider.notifier);

      notifier.startListening('u');
      await Future<void>.delayed(Duration.zero);
      notifier.clear();

      expect(container.read(birthdayProvider).birthdays, isEmpty);
      expect(container.read(birthdayProvider).isLoading, true);
    });

    test('importFromContacts throws when permission is denied', () async {
      final repo = RecordingBirthdayRepository();
      final container = ProviderContainer(
        overrides: [
          birthdayRepositoryProvider.overrideWithValue(repo),
          contactsServiceProvider.overrideWithValue(
            const _FakeContactsService(granted: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(birthdayProvider.notifier).importFromContacts('u'),
        throwsException,
      );
      expect(repo.created, isEmpty);
    });

    test(
      'importFromContacts creates one birthday per contact and returns the count',
      () async {
        final repo = RecordingBirthdayRepository();
        final container = ProviderContainer(
          overrides: [
            birthdayRepositoryProvider.overrideWithValue(repo),
            contactsServiceProvider.overrideWithValue(
              _FakeContactsService(
                contacts: [
                  ImportedBirthday(
                    name: 'A',
                    surname: 'B',
                    date: DateTime(1990, 1, 1),
                  ),
                  ImportedBirthday(
                    name: 'C',
                    surname: 'D',
                    date: DateTime(1992, 2, 2),
                  ),
                ],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final count = await container
            .read(birthdayProvider.notifier)
            .importFromContacts('u');

        expect(count, 2);
        expect(repo.created, hasLength(2));
        expect(repo.created.first.name, 'A');
      },
    );
  });

  group('Derived providers', () {
    late BirthdayModel near;
    late BirthdayModel mid;
    late BirthdayModel far;

    ProviderContainer containerWith(List<BirthdayModel> birthdays) {
      final container = ProviderContainer(
        overrides: [
          birthdayProvider.overrideWith(
            () => FakeBirthdayNotifier(
              initialState: BirthdayState(
                birthdays: birthdays,
                isLoading: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      near = _relative(
        5,
        id: 'near',
        name: 'Alice',
        surname: 'Wonderland',
        categories: const ['cat1'],
      );
      mid = _relative(
        30,
        id: 'mid',
        name: 'Bob',
        surname: 'Builder',
        categories: const ['cat1', 'cat2'],
      );
      far = _relative(
        60,
        id: 'far',
        name: 'Charlie',
        surname: 'Chocolate',
        categories: const ['cat2'],
      );
    });

    test('nextBirthdaysProvider returns the closest birthday', () {
      final container = containerWith([far, near, mid]);

      final next = container.read(nextBirthdaysProvider);

      expect(next.map((b) => b.id), ['near']);
    });

    test(
      'filteredBirthdaysProvider excludes the next and sorts by proximity',
      () {
        final container = containerWith([far, near, mid]);

        final filtered = container.read(filteredBirthdaysProvider);

        expect(filtered.map((b) => b.id), ['mid', 'far']);
      },
    );

    test('filteredBirthdaysProvider applies the search query', () {
      final container = containerWith([near, mid, far]);
      container.read(birthdaySearchProvider.notifier).update('bob');

      final filtered = container.read(filteredBirthdaysProvider);

      expect(filtered.map((b) => b.id), ['mid']);
    });

    test('filteredBirthdaysProvider requires ALL selected categories', () {
      final container = containerWith([near, mid, far]);
      container.read(birthdayCategoryFilterProvider.notifier).update([
        'cat1',
        'cat2',
      ]);

      final filtered = container.read(filteredBirthdaysProvider);

      // Only "mid" carries both categories (and it is not the next birthday).
      expect(filtered.map((b) => b.id), ['mid']);
    });

    test('categoryFilteredBirthdaysProvider keeps the next birthday', () {
      final container = containerWith([near, mid, far]);
      container.read(birthdaySearchProvider.notifier).update('alice');

      final result = container.read(categoryFilteredBirthdaysProvider);

      expect(result.map((b) => b.id), ['near']);
    });

    test('categoryFilteredBirthdaysProvider filters by category', () {
      final container = containerWith([near, mid, far]);
      container.read(birthdayCategoryFilterProvider.notifier).update(['cat2']);

      final result = container.read(categoryFilteredBirthdaysProvider);

      expect(result.map((b) => b.id).toSet(), {'mid', 'far'});
    });
  });

  group('Search and category filter notifiers', () {
    test('they expose and update their value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(birthdaySearchProvider), '');
      container.read(birthdaySearchProvider.notifier).update('x');
      expect(container.read(birthdaySearchProvider), 'x');

      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
      container.read(birthdayCategoryFilterProvider.notifier).update(['a']);
      expect(container.read(birthdayCategoryFilterProvider), ['a']);
    });
  });
}
