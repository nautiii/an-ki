import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
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
    FakeContactLinkRepository? links,
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repository),
        contactLinkRepositoryProvider.overrideWithValue(
          links ?? FakeContactLinkRepository(),
        ),
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
    await editor.delete('id-2', uid: 'u1');

    expect(repo.created, hasLength(2));
    expect(repo.updated, ['id-1']);
    expect(repo.deleted, ['id-2']);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('creates on the id it announces', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo);

    await container.read(birthdayEditorProvider.notifier).create(_input());

    expect(repo.createdIds, ['new-1']);
    expect(container.read(birthdayAdditionsProvider)?.id, 'new-1');
  });

  test('sets, mutes and resets a person reminders', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo);
    final editor = container.read(birthdayEditorProvider.notifier);

    await editor.setReminders('lea', {ReminderLead.dayBefore});
    await editor.setReminders('lea', const {});
    await editor.setReminders('lea', null);

    // Un record compare ses ensembles par identité : on les compare à part.
    expect(repo.reminderUpdates.map((update) => update.$1), [
      'lea',
      'lea',
      'lea',
    ]);
    expect(repo.reminderUpdates.map((update) => update.$2), [
      {ReminderLead.dayBefore},
      isEmpty,
      isNull,
    ]);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('writes the own wish message through the repository', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo);
    final editor = container.read(birthdayEditorProvider.notifier);

    await editor.setWishMessage('lea', 'Coucou');
    await editor.setWishMessage('lea', null);

    expect(repo.wishMessageUpdates, [('lea', 'Coucou'), ('lea', null)]);
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
        const BirthdaysAdded(
          count: 1,
          imported: false,
          first: true,
          name: 'New Person',
          id: 'new-1',
        ),
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
        const BirthdaysAdded(
          count: 1,
          imported: false,
          first: false,
          name: 'New Person',
          id: 'new-1',
        ),
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

  test('a deletion forgets the contact link on this phone', () async {
    final repo = RecordingBirthdayRepository();
    final links = FakeContactLinkRepository(
      links: {
        'u1': {
          'id-1': const ContactLink(number: '0611111111', contactName: 'Léa'),
          'id-2': const ContactLink(number: '0622222222', contactName: 'Tom'),
        },
      },
    );
    // Aucun écouteur des liaisons : une suppression depuis la liste.
    final container = makeContainer(repo, links: links);

    await container
        .read(birthdayEditorProvider.notifier)
        .delete('id-1', uid: 'u1');
    await pumpEventQueue();

    expect(repo.deleted, ['id-1']);
    expect(links.links['u1']?.keys, ['id-2']);
  });

  test('drops a deletion started on another account', () async {
    final repo = RecordingBirthdayRepository();
    final links = FakeContactLinkRepository(
      links: {
        'u2': {'id-1': const ContactLink(number: '06', contactName: '')},
      },
    );
    final container = makeContainer(repo, uid: 'u2', links: links);

    await container
        .read(birthdayEditorProvider.notifier)
        .delete('id-1', uid: 'u1');
    await pumpEventQueue();

    expect(repo.deleted, isEmpty);
    expect(links.links['u2']?.keys, ['id-1']);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('drops a deletion when the account signed out meanwhile', () async {
    final repo = RecordingBirthdayRepository();
    final container = makeContainer(repo, uid: null);

    await container
        .read(birthdayEditorProvider.notifier)
        .delete('id-1', uid: 'u1');

    expect(repo.deleted, isEmpty);
    expect(container.read(birthdayEditorProvider), isA<AsyncData<void>>());
  });

  test('publishes a failed write as an AsyncError', () async {
    final repo = RecordingBirthdayRepository(failure: Exception('denied'));
    final container = makeContainer(repo);

    await container
        .read(birthdayEditorProvider.notifier)
        .delete('id-1', uid: 'u1');

    expect(container.read(birthdayEditorProvider).hasError, isTrue);
  });

  group('createAll', () {
    test('writes the batch and announces how many', () async {
      final repo = RecordingBirthdayRepository();
      final container = makeContainer(repo, existing: [_lea]);
      final announced = <BirthdaysAdded?>[];
      container.listen(
        birthdayAdditionsProvider,
        (_, added) => announced.add(added),
      );

      await container.read(birthdayEditorProvider.notifier).createAll([
        _input(),
        _input(),
      ]);

      expect(repo.created, hasLength(2));
      expect(announced, [
        const BirthdaysAdded(count: 2, imported: false, first: false),
      ]);
    });

    test('one draft is a plain creation, named', () async {
      final repo = RecordingBirthdayRepository();
      final container = makeContainer(repo);
      final announced = <BirthdaysAdded?>[];
      container.listen(
        birthdayAdditionsProvider,
        (_, added) => announced.add(added),
      );

      await container.read(birthdayEditorProvider.notifier).createAll([
        _input(),
      ]);

      expect(repo.createdIds, hasLength(1));
      expect(announced.single?.name, 'New Person');
    });

    test('an empty list writes nothing', () async {
      final repo = RecordingBirthdayRepository();
      final container = makeContainer(repo);

      await container.read(birthdayEditorProvider.notifier).createAll([]);

      expect(repo.created, isEmpty);
    });
  });
}
