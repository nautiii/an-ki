import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
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
  Stream<List<Birthday>> watchBirthdays(String uid) =>
      Stream.error(Exception('stream failed'));
}

/// Anniversaire dont la date tombe dans [daysAhead] jours, quel que soit le
/// jour d'exécution du test.
Birthday _relative(
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
  return Birthday(
    id: id,
    name: name,
    surname: surname,
    date: BirthDate.fromDate(DateTime(1990, target.month, target.day)),
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
    late Birthday near;
    late Birthday mid;
    late Birthday far;

    ProviderContainer containerWith(List<Birthday> birthdays) =>
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

    test('agendaProvider leaves the hero out and groups the rest', () {
      final soon = _relative(6, id: 'soon', name: 'Dan', surname: 'Brown');
      final container = containerWith([far, near, mid, soon]);

      final agenda = container.read(agendaProvider);

      expect(agenda.first.period, const AgendaSoon());
      expect(agenda.first.birthdays.map((b) => b.id), ['soon']);
      expect(
        [
          for (final section in agenda)
            for (final b in section.birthdays) b.id,
        ],
        ['soon', 'mid', 'far'],
      );
    });

    test('birthdaySearchResultsProvider searches everyone, by proximity', () {
      final container = containerWith([far, near, mid]);
      container.listen(birthdaySearchResultsProvider, (_, _) {});

      expect(container.read(birthdaySearchResultsProvider).map((b) => b.id), [
        'near',
        'mid',
        'far',
      ]);

      container.read(birthdaySearchProvider.notifier).update('alice');
      expect(container.read(birthdaySearchResultsProvider).map((b) => b.id), [
        'near',
      ]);

      container.read(birthdaySearchProvider.notifier).update('');
      container.read(birthdayCategoryFilterProvider.notifier).toggle('cat2');
      expect(container.read(birthdaySearchResultsProvider).map((b) => b.id), [
        'mid',
        'far',
      ]);
    });
  });

  group('Pending deletions', () {
    final lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate.fromDate(DateTime(1990, 3, 12)),
    );
    final hugo = Birthday(
      id: 'hugo',
      name: 'Hugo',
      surname: 'Bernard',
      date: BirthDate.fromDate(DateTime(1990, 6)), // 1er juin
    );

    test('hide a birthday everywhere until it is restored', () async {
      final container = sessionContainer(
        RecordingBirthdayRepository(initial: [lea, hugo]),
      );
      container.listen(birthdaysListProvider, (_, _) {});
      container.listen(birthdaysProvider, (_, _) {});
      await container.read(birthdaysProvider.future);
      final pending = container.read(pendingDeletionsProvider.notifier);

      pending.hide('lea');
      expect(container.read(birthdaysListProvider), [hugo]);

      pending.restore('lea');
      expect(container.read(birthdaysListProvider), [lea, hugo]);
    });

    test('start empty again when the user changes', () {
      final container = sessionContainer(RecordingBirthdayRepository());
      container.listen(pendingDeletionsProvider, (_, _) {});
      container.read(pendingDeletionsProvider.notifier).hide('lea');

      container.read(_session.notifier).signIn('u2');

      expect(container.read(pendingDeletionsProvider), isEmpty);
    });
  });

  group('Search and category filter notifiers', () {
    test('they expose and update their value', () {
      final container = sessionContainer(RecordingBirthdayRepository());
      container.listen(birthdaySearchProvider, (_, _) {});
      container.listen(birthdayCategoryFilterProvider, (_, _) {});

      expect(container.read(birthdaySearchProvider), '');
      container.read(birthdaySearchProvider.notifier).update('x');
      expect(container.read(birthdaySearchProvider), 'x');

      final filters = container.read(birthdayCategoryFilterProvider.notifier);
      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
      filters
        ..toggle('a')
        ..toggle('b');
      expect(container.read(birthdayCategoryFilterProvider), ['a', 'b']);
      filters.toggle('a');
      expect(container.read(birthdayCategoryFilterProvider), ['b']);
      filters.clear();
      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
    });

    test('they reset when the user changes', () {
      final container = sessionContainer(RecordingBirthdayRepository());
      container.listen(birthdaySearchProvider, (_, _) {});
      container.listen(birthdayCategoryFilterProvider, (_, _) {});
      container.read(birthdaySearchProvider.notifier).update('x');
      container.read(birthdayCategoryFilterProvider.notifier).toggle('a');

      container.read(_session.notifier).signIn(null);

      expect(container.read(birthdaySearchProvider), '');
      expect(container.read(birthdayCategoryFilterProvider), isEmpty);
    });

    test('they start over once the search screen is gone', () async {
      final container = sessionContainer(RecordingBirthdayRepository());
      final search = container.listen(birthdaySearchProvider, (_, _) {});
      container.read(birthdaySearchProvider.notifier).update('x');

      search.close();
      await container.pump();

      expect(container.read(birthdaySearchProvider), '');
    });
  });
}
