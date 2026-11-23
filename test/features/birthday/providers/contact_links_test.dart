import 'dart:async';

import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:an_ki/features/birthday/providers/contact_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _lea = ContactLink(number: '0611111111', contactName: 'Léa Martin');
const _hugo = ContactLink(number: '0622222222', contactName: 'Hugo');

/// Compte connecté que le test change en cours de route.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);

void main() {
  late FakeContactLinkRepository repository;
  late FakePhoneContactService phone;

  ProviderContainer makeContainer({String? uid = 'u1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        contactLinkRepositoryProvider.overrideWithValue(repository),
        phoneContactServiceProvider.overrideWithValue(phone),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container
      ..listen(contactLinksProvider, (_, _) {})
      ..listen(contactLinkerProvider, (_, _) {});
    return container;
  }

  /// Conteneur dont le compte change par `_uidProvider`.
  ProviderContainer switchingContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        contactLinkRepositoryProvider.overrideWithValue(repository),
        phoneContactServiceProvider.overrideWithValue(phone),
        currentUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
      ],
    );
    container.listen(contactLinksProvider, (_, _) {});
    return container;
  }

  setUp(() {
    repository = FakeContactLinkRepository();
    phone = FakePhoneContactService();
  });

  group('ContactLinks', () {
    test('reads the links of the signed-in account only', () async {
      repository.links
        ..['u1'] = {'b1': _lea}
        ..['u2'] = {'b9': _hugo};
      final container = makeContainer();

      expect(await container.read(contactLinksProvider.future), {'b1': _lea});
      expect(container.read(contactLinkProvider('b1')), _lea);
      expect(container.read(contactLinkProvider('b9')), isNull);
    });

    test('is empty when signed out, and writes nothing', () async {
      final container = makeContainer(uid: null);

      expect(await container.read(contactLinksProvider.future), isEmpty);
      await container.read(contactLinksProvider.notifier).link('b1', _lea);
      expect(repository.writes, 0);
    });

    test('link and unlink update the state and the storage', () async {
      final container = makeContainer();
      final links = container.read(contactLinksProvider.notifier);

      await links.link('b1', _lea);
      await links.link('b2', _hugo);
      expect(container.read(contactLinksProvider).value, {
        'b1': _lea,
        'b2': _hugo,
      });

      await links.unlink('b1');
      expect(container.read(contactLinksProvider).value, {'b2': _hugo});
      expect(repository.links['u1'], {'b2': _hugo});
    });

    test('two quick changes both land, in order', () async {
      final container = makeContainer();
      final links = container.read(contactLinksProvider.notifier);

      await Future.wait([links.link('b1', _lea), links.link('b2', _hugo)]);

      expect(repository.links['u1'], {'b1': _lea, 'b2': _hugo});
    });

    test('follows the account: another uid reads its own links', () async {
      repository.links
        ..['u1'] = {'b1': _lea}
        ..['u2'] = {'b9': _hugo};
      final container = switchingContainer();
      expect(await container.read(contactLinksProvider.future), {'b1': _lea});

      container.read(_uidProvider.notifier).set('u2');
      expect(await container.read(contactLinksProvider.future), {'b9': _hugo});

      await container.read(contactLinksProvider.notifier).link('b8', _lea);
      expect(repository.links['u1'], {'b1': _lea});
      expect(repository.links['u2'], {'b9': _hugo, 'b8': _lea});
    });

    test('a change started before an account switch writes nothing', () async {
      repository.pendingFetch = Completer();
      final container = switchingContainer();

      final linking = container
          .read(contactLinksProvider.notifier)
          .link('b1', _lea);
      container.read(_uidProvider.notifier).set('u2');
      repository.pendingFetch!.complete();
      await linking;

      expect(repository.writes, 0);
      expect(repository.links, isEmpty);
    });

    test('two failed writes in a row read the storage back', () async {
      repository.links['u1'] = {'b1': _lea};
      final container = makeContainer();
      await container.read(contactLinksProvider.future);
      repository.failure = ContactLinkFailure.storageFailed;
      final links = container.read(contactLinksProvider.notifier);

      final results = await Future.wait([
        links
            .link('b2', _hugo)
            .then<Object?>((_) => null, onError: (Object e) => e),
        links.unlink('b1').then<Object?>((_) => null, onError: (Object e) => e),
      ]);

      expect(results, everyElement(ContactLinkFailure.storageFailed));
      expect(await container.read(contactLinksProvider.future), {'b1': _lea});
    });

    test('a failed write restores the links and throws', () async {
      repository.links['u1'] = {'b1': _lea};
      final container = makeContainer();
      await container.read(contactLinksProvider.future);
      repository.failure = ContactLinkFailure.storageFailed;

      await expectLater(
        container.read(contactLinksProvider.notifier).unlink('b1'),
        throwsA(ContactLinkFailure.storageFailed),
      );
      expect(await container.read(contactLinksProvider.future), {'b1': _lea});
    });
  });

  group('ContactLinker', () {
    test('pick links the number chosen in the picker', () async {
      phone.picked = const PickedPhone(
        number: '0611111111',
        contactName: 'Léa Martin',
      );
      final container = makeContainer();

      final linked = await container
          .read(contactLinkerProvider.notifier)
          .pick('b1');

      expect(linked, isTrue);
      expect(container.read(contactLinkProvider('b1')), _lea);
      expect(container.read(contactLinkerProvider), isA<AsyncData<void>>());
    });

    test('pick changes nothing when the picker is closed', () async {
      final container = makeContainer();

      expect(
        await container.read(contactLinkerProvider.notifier).pick('b1'),
        isFalse,
      );
      expect(repository.writes, 0);
      expect(container.read(contactLinkerProvider), isA<AsyncData<void>>());
    });

    test('pick ignores a second tap while the picker is open', () async {
      final container = makeContainer();
      final linker = container.read(contactLinkerProvider.notifier);
      phone.pendingPick = Completer();

      final first = linker.pick('b1');
      expect(await linker.pick('b1'), isFalse);
      phone.pendingPick!.complete(null);
      await first;

      expect(phone.picks, 1);
    });

    test('pick publishes pickerUnavailable', () async {
      phone.pickError = const PhoneContactUnavailable();
      final container = makeContainer();

      expect(
        await container.read(contactLinkerProvider.notifier).pick('b1'),
        isFalse,
      );
      expect(
        container.read(contactLinkerProvider).error,
        ContactLinkFailure.pickerUnavailable,
      );
    });

    test('pick publishes storageFailed when the link is not saved', () async {
      phone.picked = const PickedPhone(number: '0611111111', contactName: '');
      repository.failure = ContactLinkFailure.storageFailed;
      final container = makeContainer();

      expect(
        await container.read(contactLinkerProvider.notifier).pick('b1'),
        isFalse,
      );
      expect(
        container.read(contactLinkerProvider).error,
        ContactLinkFailure.storageFailed,
      );
      await container.read(contactLinksProvider.future);
      expect(container.read(contactLinkProvider('b1')), isNull);
    });

    test('unlink returns the link removed, restore puts it back', () async {
      repository.links['u1'] = {'b1': _lea};
      final container = makeContainer();
      final linker = container.read(contactLinkerProvider.notifier);

      final removed = await linker.unlink('b1');
      expect(removed, _lea);
      expect(container.read(contactLinkProvider('b1')), isNull);

      await linker.restore('b1', removed!);
      expect(container.read(contactLinkProvider('b1')), _lea);
      expect(repository.links['u1'], {'b1': _lea});
    });

    test('unlink returns null for a record that is not linked', () async {
      final container = makeContainer();

      expect(
        await container.read(contactLinkerProvider.notifier).unlink('b1'),
        isNull,
      );
      expect(repository.writes, 0);
    });

    test('dial and message open the apps with the number', () async {
      final container = makeContainer();
      final linker = container.read(contactLinkerProvider.notifier);

      expect(await linker.dial('0611111111'), isTrue);
      expect(await linker.message('0611111111', 'Coucou'), isTrue);

      expect(phone.dialed, ['0611111111']);
      expect(phone.texts, [('0611111111', 'Coucou')]);
    });

    test('a later success clears the failure shown before', () async {
      phone.opens = false;
      final container = makeContainer();
      final linker = container.read(contactLinkerProvider.notifier);
      await linker.dial('06');
      expect(container.read(contactLinkerProvider).hasError, isTrue);

      phone.opens = true;
      await linker.message('06', '');
      expect(container.read(contactLinkerProvider), isA<AsyncData<void>>());
    });

    test('dial publishes appUnavailable when no app opens', () async {
      phone.opens = false;
      final container = makeContainer();

      expect(
        await container.read(contactLinkerProvider.notifier).dial('06'),
        isFalse,
      );
      expect(
        container.read(contactLinkerProvider).error,
        ContactLinkFailure.appUnavailable,
      );
    });
  });

  test('contactLinkSupportedProvider follows the service', () {
    phone = FakePhoneContactService(isSupported: false);
    final container = makeContainer();

    expect(container.read(contactLinkSupportedProvider), isFalse);
  });
}
