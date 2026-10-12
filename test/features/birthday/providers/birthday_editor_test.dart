import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

BirthdayDraft _input() => BirthdayDraft(
  name: 'New',
  surname: 'Person',
  date: BirthDate.fromDate(DateTime(2000)),
);

void main() {
  ProviderContainer makeContainer(
    RecordingBirthdayRepository repository, {
    String? uid = 'u1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue(uid),
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

  test('does nothing without a session', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo, uid: null);

    await container.read(birthdayEditorProvider.notifier).create(_input());

    expect(repo.created, isEmpty);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('publishes a failed write as an AsyncError', () async {
    final repo = RecordingBirthdayRepository(failure: Exception('denied'));
    final container = makeContainer(repo);

    await container.read(birthdayEditorProvider.notifier).delete('id-1');

    expect(container.read(birthdayEditorProvider).hasError, isTrue);
  });
}
