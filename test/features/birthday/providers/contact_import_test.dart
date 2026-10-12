import 'dart:async';

import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/features/birthday/providers/contact_import.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

class _FakeContactsService extends ContactsService {
  _FakeContactsService({this.granted = true, this.contacts = const []});

  final bool granted;
  final List<ImportedBirthday> contacts;

  /// Quand défini, la lecture attend ce Completer (import en cours).
  Completer<void>? pendingRead;
  int reads = 0;

  @override
  Future<bool> requestReadPermission() async => granted;

  @override
  Future<List<ImportedBirthday>> fetchBirthdays() async {
    reads++;
    await pendingRead?.future;
    return contacts;
  }
}

void main() {
  late RecordingBirthdayRepository repo;

  ProviderContainer makeContainer(
    _FakeContactsService contacts, {
    String? uid = 'u1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repo),
        contactsServiceProvider.overrideWithValue(contacts),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container.listen(contactImportProvider, (_, _) {});
    return container;
  }

  setUp(() => repo = RecordingBirthdayRepository());

  test('reports a denied permission without writing', () async {
    final container = makeContainer(_FakeContactsService(granted: false));

    await container.read(contactImportProvider.notifier).run();

    expect(
      container.read(contactImportProvider).error,
      ContactImportFailure.permissionDenied,
    );
    expect(repo.created, isEmpty);
  });

  test('writes one birthday per contact and publishes the count', () async {
    final container = makeContainer(
      _FakeContactsService(
        contacts: const [
          ImportedBirthday(
            name: 'A',
            surname: 'B',
            month: 1,
            day: 1,
            year: 1990,
          ),
          ImportedBirthday(
            name: 'C',
            surname: 'D',
            month: 2,
            day: 2,
            year: 1992,
          ),
        ],
      ),
    );

    await container.read(contactImportProvider.notifier).run();

    expect(container.read(contactImportProvider).value, 2);
    expect(repo.created.map((input) => input.name), ['A', 'C']);
  });

  test('keeps the year of a contact, never invents one', () async {
    final container = makeContainer(
      _FakeContactsService(
        contacts: const [
          ImportedBirthday(name: 'Mamie', surname: '', month: 10, day: 15),
          ImportedBirthday(
            name: 'Léa',
            surname: 'Martin',
            month: 3,
            day: 12,
            year: 1990,
          ),
        ],
      ),
    );

    await container.read(contactImportProvider.notifier).run();

    expect(repo.created.map((draft) => draft.date), const [
      BirthDate(month: 10, day: 15),
      BirthDate(year: 1990, month: 3, day: 12),
    ]);
  });

  test('ignores a second run while one is in progress', () async {
    final contacts = _FakeContactsService()..pendingRead = Completer<void>();
    final container = makeContainer(contacts);
    final notifier = container.read(contactImportProvider.notifier);

    final first = notifier.run();
    await notifier.run();
    contacts.pendingRead!.complete();
    await first;

    expect(contacts.reads, 1);
  });

  test('does nothing without a session', () async {
    final contacts = _FakeContactsService();
    final container = makeContainer(contacts, uid: null);

    await container.read(contactImportProvider.notifier).run();

    expect(contacts.reads, 0);
    expect(container.read(contactImportProvider).value, isNull);
  });
}
