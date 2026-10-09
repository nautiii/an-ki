import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// Session pilotable par le test (connexion, changement de compte…).
final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void signIn(String? uid) => state = uid;
}

class _ErroringBirthdayRepository extends FakeBirthdayRepository {
  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) =>
      Stream.error(Exception('stream failed'));
}

/// Anniversaire dont la date tombe dans [daysAhead] jours, quel que soit le
/// jour d'exécution du test.
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
    name: name,
    surname: surname,
    date: DateTime(1990, target.month, target.day),
    categories: categories,
  );
}

void main() {
  ProviderContainer sessionContainer(FakeBirthdayRepository repository) =>
      ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          birthdayRepositoryProvider.overrideWithValue(repository),
          currentUidProvider.overrideWith((ref) => ref.watch(_session)),
        ],
      );

  group('birthdaysProvider', () {
    test('streams the birthdays of the signed-in user', () async {
      final repo = RecordingBirthdayRepository(
        initial: [_relative(5, id: '1', name: 'A', surname: 'B')],
      );
      final container = sessionContainer(repo);
      container.listen(birthdaysProvider, (_, _) {});

      final birthdays = await container.read(birthdaysProvider.future);

      expect(birthdays.single.id, '1');
      expect(repo.watchedUids, ['u1']);
    });

    test('follows the session without manual reset', () async {
      final repo = RecordingBirthdayRepository(
        initial: [_relative(5, id: '1', name: 'A', surname: 'B')],
      );
      final container = sessionContainer(repo);
      container.listen(birthdaysProvider, (_, _) {});
      await container.read(birthdaysProvider.future);

      container.read(_session.notifier).signIn('u2');
      await container.read(birthdaysProvider.future);
      expect(repo.watchedUids, ['u1', 'u2']);

      container.read(_session.notifier).signIn(null);
      expect(await container.read(birthdaysProvider.future), isEmpty);
      expect(repo.watchedUids, ['u1', 'u2']);
    });

    test('loading lasts until the first list, list empty on error', () async {
      final container = sessionContainer(_ErroringBirthdayRepository());
      container.listen(birthdaysProvider, (_, _) {});

      expect(container.read(birthdaysLoadingProvider), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(birthdaysProvider).hasError, isTrue);
      expect(container.read(birthdaysLoadingProvider), isFalse);
      expect(container.read(birthdaysListProvider), isEmpty);
    });

    test('loading ends with the first list', () async {
      final container = sessionContainer(RecordingBirthdayRepository());
      container.listen(birthdaysProvider, (_, _) {});

      await container.read(birthdaysProvider.future);

      expect(container.read(birthdaysLoadingProvider), isFalse);
    });
  });

  group('Derived providers', () {
    late BirthdayModel near;
    late BirthdayModel mid;
    late BirthdayModel far;

    ProviderContainer containerWith(List<BirthdayModel> birthdays) =>
        ProviderContainer.test(
          overrides: [
            birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
            currentUidProvider.overrideWithValue('u1'),
          ],
        );

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

      // Seul « mid » porte les deux catégories (et ce n'est pas le prochain).
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
      final container = sessionContainer(RecordingBirthdayRepository());

      expect(container.read(birthdaySearchProvider), '');
      container.read(birthdaySearchProvider.notifier).update('x');
      expect(container.read(birthdaySearchProvider), 'x');

      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
      container.read(birthdayCategoryFilterProvider.notifier).update(['a']);
      expect(container.read(birthdayCategoryFilterProvider), ['a']);
    });

    test('they reset when the user changes', () {
      final container = sessionContainer(RecordingBirthdayRepository());
      container.listen(birthdaySearchProvider, (_, _) {});
      container.listen(birthdayCategoryFilterProvider, (_, _) {});
      container.read(birthdaySearchProvider.notifier).update('x');
      container.read(birthdayCategoryFilterProvider.notifier).update(['a']);

      container.read(_session.notifier).signIn(null);

      expect(container.read(birthdaySearchProvider), '');
      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
    });
  });
}
