import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('an_ki/phone_contact');
  const service = PhoneContactService();
  final calls = <MethodCall>[];

  void mockChannel(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  setUp(calls.clear);

  group('pickPhone', () {
    test('returns the picked number and its contact, trimmed', () async {
      mockChannel(
        (_) => {'number': ' 06 12 34 56 78 ', 'name': ' Léa Martin '},
      );

      expect(
        await service.pickPhone(),
        const PickedPhone(number: '06 12 34 56 78', contactName: 'Léa Martin'),
      );
      expect(calls.single.method, 'pickPhone');
    });

    test('keeps a number whose contact has no name', () async {
      mockChannel((_) => {'number': '+33612345678'});

      expect(
        await service.pickPhone(),
        const PickedPhone(number: '+33612345678', contactName: ''),
      );
    });

    test('returns null when the picker is closed', () async {
      mockChannel((_) => null);

      expect(await service.pickPhone(), isNull);
    });

    test('throws when the picker is unavailable', () async {
      mockChannel((_) => throw PlatformException(code: 'unavailable'));

      await expectLater(
        service.pickPhone(),
        throwsA(isA<PhoneContactUnavailable>()),
      );
    });

    test('returns null when a picker is already open', () async {
      mockChannel((_) => throw PlatformException(code: 'busy'));

      expect(await service.pickPhone(), isNull);
    });

    test('throws when the channel is missing', () async {
      // Aucun gestionnaire : MissingPluginException, comme hors Android.
      await expectLater(
        service.pickPhone(),
        throwsA(isA<PhoneContactUnavailable>()),
      );
    });

    test('throws when the picked row has no number', () async {
      mockChannel((_) => {'number': '  ', 'name': 'Léa'});

      await expectLater(
        service.pickPhone(),
        throwsA(isA<PhoneContactUnavailable>()),
      );
    });
  });

  group('dial and sendSms', () {
    test('dial passes the number and reports the opening', () async {
      mockChannel((_) => true);

      expect(await service.dial('0612345678'), isTrue);
      expect(calls.single.method, 'dial');
      expect(calls.single.arguments, {'number': '0612345678'});
    });

    test('sendSms passes the number and the text', () async {
      mockChannel((_) => true);

      expect(
        await service.sendSms('0612345678', 'Joyeux anniversaire'),
        isTrue,
      );
      expect(calls.single.method, 'sendSms');
      expect(calls.single.arguments, {
        'number': '0612345678',
        'body': 'Joyeux anniversaire',
      });
    });

    test('report false when no app handles them', () async {
      mockChannel((_) => false);

      expect(await service.dial('0612345678'), isFalse);
      expect(await service.sendSms('0612345678', 'Coucou'), isFalse);
    });

    test('report false on a platform error or a missing channel', () async {
      expect(await service.dial('0612345678'), isFalse);

      mockChannel((_) => throw PlatformException(code: 'bad_args'));
      expect(await service.sendSms('0612345678', 'Coucou'), isFalse);
    });
  });

  test('isSupported follows the platform', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(service.isSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(service.isSupported, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
