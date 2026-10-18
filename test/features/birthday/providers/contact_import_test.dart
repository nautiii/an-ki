import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/contact_import.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _lea = ImportedBirthday(
  name: 'Léa',
  surname: 'Martin',
  month: 3,
  day: 12,
  year: 1990,
);
const _hugo = ImportedBirthday(
  name: 'Hugo',
  surname: 'Bernard',
  month: 10,
  day: 15,
);
const _mamie = ImportedBirthday(name: 'Mamie', surname: '', month: 11, day: 2);

const _savedLea = Birthday(
  id: 'b1',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(year: 1990, month: 3, day: 12),
);

void main() {
  late RecordingBirthdayRepository repo;

  ProviderContainer makeContainer(
    FakeContactsService contacts, {
    String? uid = 'u1',
    List<Birthday> existing = const [],
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repo),
        contactsServiceProvider.overrideWithValue(contacts),
        currentUidProvider.overrideWithValue(uid),
        birthdaysProvider.overrideWithValue(AsyncData(existing)),
        // Lundi 12 octobre 2026.
        todayProvider.overrideWithValue(DateTime(2026, 10, 12)),
      ],
    );
    // L'écran écoute l'aperçu et les cochés, qui gardent le reste en vie.
    container.listen(contactImportPreviewProvider, (_, _) {});
    container.listen(contactImportTickedProvider, (_, _) {});
    return container;
  }

  List<String> names(List<BirthdayDraft> drafts) => [
    for (final draft in drafts) draft.fullName,
  ];

  setUp(() => repo = RecordingBirthdayRepository());

  test('has nothing to show until loaded', () {
    final container = makeContainer(FakeContactsService());

    expect(container.read(contactImportPreviewProvider).value, isNull);
    expect(container.read(contactImportTickedProvider), isEmpty);
  });

  test('previews the contacts, the soonest first, all ticked', () async {
    final container = makeContainer(
      FakeContactsService(contacts: const [_mamie, _lea, _hugo]),
      existing: [_savedLea],
    );

    await container.read(contactImportProvider.notifier).load();

    final preview = container.read(contactImportPreviewProvider).value!;
    expect(names(preview.fresh), ['Hugo Bernard', 'Mamie']);
    // L'année d'un contact n'est jamais inventée.
    expect(preview.fresh.first.date, const BirthDate(month: 10, day: 15));
    expect(names(preview.known), ['Léa Martin']);
    expect(names(container.read(contactImportTickedProvider)), [
      'Hugo Bernard',
      'Mamie',
    ]);
    expect(repo.created, isEmpty);
  });

  test(
    'moves to « already in AnKi » whoever the list gains meanwhile',
    () async {
      final live = _LiveBirthdayRepository();
      addTearDown(live.close);
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          birthdayRepositoryProvider.overrideWithValue(live),
          contactsServiceProvider.overrideWithValue(
            FakeContactsService(contacts: const [_lea]),
          ),
          currentUidProvider.overrideWithValue('u1'),
          todayProvider.overrideWithValue(DateTime(2026, 10, 12)),
        ],
      );
      container.listen(contactImportPreviewProvider, (_, _) {});
      live.birthdays.add(const []);
      await container.read(contactImportProvider.notifier).load();
      expect(names(container.read(contactImportPreviewProvider).value!.fresh), [
        'Léa Martin',
      ]);

      // Léa arrive dans la liste pendant que l'aperçu est ouvert.
      live.birthdays.add([_savedLea]);
      await Future<void>.delayed(Duration.zero);

      final preview = container.read(contactImportPreviewProvider).value!;
      expect(preview.fresh, isEmpty);
      expect(names(preview.known), ['Léa Martin']);
    },
  );

  test('a refusal that can be asked again is a denied permission', () async {
    final contacts = FakeContactsService(access: ContactsAccess.denied);
    final container = makeContainer(contacts);

    await container.read(contactImportProvider.notifier).load();

    expect(
      container.read(contactImportPreviewProvider).error,
      ContactImportFailure.permissionDenied,
    );
    expect(contacts.reads, 0);
  });

  test('a lasting refusal is a blocked permission', () async {
    final container = makeContainer(
      FakeContactsService(access: ContactsAccess.blocked),
    );

    await container.read(contactImportProvider.notifier).load();

    expect(
      container.read(contactImportPreviewProvider).error,
      ContactImportFailure.permissionBlocked,
    );
  });

  test('a plugin error means the contacts are unreadable', () async {
    final container = makeContainer(
      FakeContactsService(failure: PlatformException(code: 'failed')),
    );

    await container.read(contactImportProvider.notifier).load();

    expect(
      container.read(contactImportPreviewProvider).error,
      ContactImportFailure.unreadable,
    );
  });

  test('ignores a second load while one is in progress', () async {
    final contacts = FakeContactsService()..pendingRead = Completer<void>();
    final container = makeContainer(contacts);
    final notifier = container.read(contactImportProvider.notifier);

    final first = notifier.load();
    await notifier.load();
    contacts.pendingRead!.complete();
    await first;

    expect(contacts.reads, 1);
  });

  test('reloads after the settings only once access is granted', () async {
    final contacts = FakeContactsService(
      access: ContactsAccess.blocked,
      contacts: const [_hugo],
    );
    final container = makeContainer(contacts);
    final notifier = container.read(contactImportProvider.notifier);
    await notifier.load();

    await notifier.reloadIfAllowed();
    expect(contacts.reads, 0);

    contacts.access = ContactsAccess.granted;
    await notifier.reloadIfAllowed();

    expect(contacts.reads, 1);
    expect(
      container.read(contactImportPreviewProvider).value?.fresh,
      hasLength(1),
    );
  });

  test('opens the app settings', () async {
    final contacts = FakeContactsService();
    final container = makeContainer(contacts);

    await container.read(contactImportProvider.notifier).openAppSettings();

    expect(contacts.settingsOpened, 1);
  });

  group('ticks', () {
    test('untick one contact, then tick it again', () async {
      final container = makeContainer(
        FakeContactsService(contacts: const [_lea, _hugo, _mamie]),
      );
      await container.read(contactImportProvider.notifier).load();
      final exclusions = container.read(
        contactImportExclusionsProvider.notifier,
      );
      final hugo = container.read(contactImportTickedProvider).first;

      exclusions.toggle(hugo);
      expect(names(container.read(contactImportTickedProvider)), [
        'Mamie',
        'Léa Martin',
      ]);

      exclusions.toggle(hugo);
      expect(container.read(contactImportTickedProvider), hasLength(3));
    });

    test('untick all when all are ticked, else tick all', () async {
      final container = makeContainer(
        FakeContactsService(contacts: const [_lea, _hugo, _mamie]),
      );
      await container.read(contactImportProvider.notifier).load();
      final exclusions = container.read(
        contactImportExclusionsProvider.notifier,
      );
      final fresh = container.read(contactImportPreviewProvider).value!.fresh;

      exclusions.toggleAll(fresh);
      expect(container.read(contactImportTickedProvider), isEmpty);

      exclusions.toggle(fresh.first);
      exclusions.toggleAll(fresh);
      expect(container.read(contactImportTickedProvider), hasLength(3));
    });
  });

  group('add', () {
    test('writes the given contacts and counts them', () async {
      final container = makeContainer(
        FakeContactsService(contacts: const [_lea, _hugo]),
      );
      final notifier = container.read(contactImportProvider.notifier);
      await notifier.load();

      final added = notifier.add(container.read(contactImportTickedProvider));

      expect(added, 2);
      expect(names(repo.created), ['Hugo Bernard', 'Léa Martin']);
    });

    test('writes nothing without a session or a contact', () async {
      final noSession = makeContainer(
        FakeContactsService(contacts: const [_lea]),
        uid: null,
      );
      final notifier = noSession.read(contactImportProvider.notifier);
      await notifier.load();
      expect(notifier.add(noSession.read(contactImportTickedProvider)), 0);

      final signedIn = makeContainer(FakeContactsService());
      expect(signedIn.read(contactImportProvider.notifier).add(const []), 0);

      expect(repo.created, isEmpty);
    });
  });
}

/// Dépôt dont la liste d'anniversaires change quand le test le décide.
class _LiveBirthdayRepository extends RecordingBirthdayRepository {
  final birthdays = StreamController<List<Birthday>>.broadcast();

  @override
  Stream<List<Birthday>> watchBirthdays(String uid) => birthdays.stream;

  Future<void> close() => birthdays.close();
}
