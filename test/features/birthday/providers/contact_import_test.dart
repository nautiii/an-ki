import 'dart:async';

import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
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

    expect(container.read(contactImportProvider).hasError, isTrue);
    expect(repo.created, isEmpty);
  });

  test('writes one birthday per contact and publishes the count', () async {
    final container = makeContainer(
      _FakeContactsService(
        contacts: [
          ImportedBirthday(name: 'A', surname: 'B', date: DateTime(1990)),
          ImportedBirthday(name: 'C', surname: 'D', date: DateTime(1992, 2, 2)),
        ],
      ),
    );

    await container.read(contactImportProvider.notifier).run();

    expect(container.read(contactImportProvider).value, 2);
    expect(repo.created.map((input) => input.name), ['A', 'C']);
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
