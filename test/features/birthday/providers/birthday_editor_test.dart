import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

BirthdayDraft _input() => BirthdayDraft(
  name: 'New',
  surname: 'Person',
  date: BirthDate.fromDate(DateTime(2000)),
);

const _lea = Birthday(
  id: 'lea',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(month: 3, day: 12),
);

void main() {
  ProviderContainer makeContainer(
    RecordingBirthdayRepository repository, {
    String? uid = 'u1',
    List<Birthday> existing = const [],
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue(uid),
        birthdaysProvider.overrideWithValue(AsyncData(existing)),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(birthdayEditorProvider, (_, _) {});
    return container;
  }

  test('create, edit and delete forward to the repository', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo);
    final editor = container.read(birthdayEditorProvider.notifier);

    await editor.create(_input());
    await editor.edit('id-1', _input());
    await editor.delete('id-2');

    expect(repo.created, hasLength(2));
    expect(repo.updated, ['id-1']);
    expect(repo.deleted, ['id-2']);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('marks and unmarks a wish through the repository', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo);
    final editor = container.read(birthdayEditorProvider.notifier);

    await editor.markWished('id-1', 2026);
    await editor.unmarkWished('id-1', 2026);

    expect(repo.wished, [('id-1', 2026)]);
    expect(repo.unwished, [('id-1', 2026)]);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('publishes a failed wish as an AsyncError', () async {
    final repo = RecordingBirthdayRepository(failure: Exception('offline'));
    final container = makeContainer(repo);

    await container.read(birthdayEditorProvider.notifier).markWished('id', 1);

    expect(container.read(birthdayEditorProvider).hasError, isTrue);
  });

  test('does nothing without a session', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo, uid: null);

    await container.read(birthdayEditorProvider.notifier).create(_input());

    expect(repo.created, isEmpty);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
    expect(container.read(birthdayAdditionsProvider), isNull);
  });

  group('reports each creation', () {
    test('the first birthday of an empty agenda', () async {
      final container = makeContainer(RecordingBirthdayRepository());

      await container.read(birthdayEditorProvider.notifier).create(_input());

      expect(
        container.read(birthdayAdditionsProvider),
        const BirthdaysAdded(count: 1, imported: false, first: true),
      );
    });

    test('one more birthday in a filled agenda', () async {
      final container = makeContainer(
        RecordingBirthdayRepository(),
        existing: const [_lea],
      );

      await container.read(birthdayEditorProvider.notifier).create(_input());

      expect(
        container.read(birthdayAdditionsProvider),
        const BirthdaysAdded(count: 1, imported: false, first: false),
      );
    });

    test('but not an edit', () async {
      final container = makeContainer(RecordingBirthdayRepository());

      await container
          .read(birthdayEditorProvider.notifier)
          .edit('id-1', _input());

      expect(container.read(birthdayAdditionsProvider), isNull);
    });
  });

  test('publishes a failed write as an AsyncError', () async {
    final repo = RecordingBirthdayRepository(failure: Exception('denied'));
    final container = makeContainer(repo);

    await container.read(birthdayEditorProvider.notifier).delete('id-1');

    expect(container.read(birthdayEditorProvider).hasError, isTrue);
  });
}
