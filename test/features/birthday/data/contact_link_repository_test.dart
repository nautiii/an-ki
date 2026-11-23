import 'dart:convert';

import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/platform_mocks.dart';

const _lea = ContactLink(number: '06 11 11 11 11', contactName: 'Léa Martin');
const _hugo = ContactLink(number: '+33622222222', contactName: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBiometricChannels channels;
  const repository = ContactLinkRepository(FlutterSecureStorage());

  setUp(() {
    channels = FakeBiometricChannels()..install();
    addTearDown(channels.uninstall);
  });

  test('reads nothing for an account without links', () async {
    expect(await repository.fetchLinks('u1'), isEmpty);
  });

  test('saves and reads back the links of one account', () async {
    await repository.saveLinks('u1', const {'b1': _lea, 'b2': _hugo});

    expect(await repository.fetchLinks('u1'), {'b1': _lea, 'b2': _hugo});
    expect(channels.storage.keys, ['contact_links_u1']);
  });

  test('keeps each account apart on the same phone', () async {
    await repository.saveLinks('u1', const {'b1': _lea});
    await repository.saveLinks('u2', const {'b9': _hugo});

    expect(await repository.fetchLinks('u1'), {'b1': _lea});
    expect(await repository.fetchLinks('u2'), {'b9': _hugo});
  });

  test('saving no link removes the entry', () async {
    await repository.saveLinks('u1', const {'b1': _lea});
    await repository.saveLinks('u1', const {});

    expect(channels.storage, isEmpty);
  });

  test('deleteAllUserLinks erases one account only', () async {
    await repository.saveLinks('u1', const {'b1': _lea});
    await repository.saveLinks('u2', const {'b9': _hugo});

    await repository.deleteAllUserLinks('u1');

    expect(await repository.fetchLinks('u1'), isEmpty);
    expect(await repository.fetchLinks('u2'), {'b9': _hugo});
  });

  test('skips unreadable entries and links without a number', () async {
    channels.storage['contact_links_u1'] = jsonEncode({
      'b1': {'number': '0611111111', 'name': 'Léa'},
      'b2': {'number': '  '},
      'b3': {'name': 'Sans numéro'},
      'b4': 'pas une liaison',
      'b5': {'number': '0622222222', 'name': 42},
    });

    expect(await repository.fetchLinks('u1'), {
      'b1': const ContactLink(number: '0611111111', contactName: 'Léa'),
      'b5': const ContactLink(number: '0622222222', contactName: ''),
    });
  });

  test('reads nothing from a corrupted entry', () async {
    channels.storage['contact_links_u1'] = '{pas du json';
    expect(await repository.fetchLinks('u1'), isEmpty);

    channels.storage['contact_links_u1'] = '["une", "liste"]';
    expect(await repository.fetchLinks('u1'), isEmpty);
  });

  group('when the storage fails', () {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'keystore'),
          );
    });

    test('a read gives no link', () async {
      expect(await repository.fetchLinks('u1'), isEmpty);
    });

    test('a write throws storageFailed', () async {
      await expectLater(
        repository.saveLinks('u1', const {'b1': _lea}),
        throwsA(ContactLinkFailure.storageFailed),
      );
      await expectLater(
        repository.deleteAllUserLinks('u1'),
        throwsA(ContactLinkFailure.storageFailed),
      );
    });
  });
}
