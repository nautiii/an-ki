import 'package:an_ki/core/services/contacts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_contacts');

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  group('ContactsService', () {
    test('fetchBirthdays returns an empty list when there are no contacts', () async {
      mockChannel((call) async => <dynamic>[]);

      final result = await const ContactsService().fetchBirthdays();

      expect(result, isEmpty);
    });

    test('fetchBirthdays propagates plugin errors', () async {
      mockChannel((call) async => throw PlatformException(code: 'failed'));

      await expectLater(
        const ContactsService().fetchBirthdays(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
