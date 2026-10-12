import 'package:an_ki/core/services/contacts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
    test(
      'fetchBirthdays returns an empty list when there are no contacts',
      () async {
        mockChannel((call) async => <dynamic>[]);

        final result = await const ContactsService().fetchBirthdays();

        expect(result, isEmpty);
      },
    );

    test(
      'fetchBirthdays keeps birthdays only, with their year when known',
      () async {
        // Contacts encodés par le plugin lui-même : le format du canal suit
        // sa version.
        mockChannel(
          (call) async => [
            const Contact(
              name: Name(first: 'Léa', last: 'Martin'),
              events: [
                Event(
                  year: 1990,
                  month: 3,
                  day: 12,
                  label: Label(EventLabel.birthday),
                ),
              ],
            ).toJson(),
            const Contact(
              name: Name(first: 'Mamie'),
              events: [
                Event(month: 10, day: 15, label: Label(EventLabel.birthday)),
              ],
            ).toJson(),
            const Contact(
              name: Name(first: 'Hugo', last: 'Bernard'),
              events: [
                Event(
                  year: 2015,
                  month: 6,
                  day: 1,
                  label: Label(EventLabel.anniversary),
                ),
              ],
            ).toJson(),
          ],
        );

        final result = await const ContactsService().fetchBirthdays();

        expect(
          [for (final b in result) (b.name, b.surname, b.year, b.month, b.day)],
          [('Léa', 'Martin', 1990, 3, 12), ('Mamie', '', null, 10, 15)],
        );
      },
    );

    test('fetchBirthdays propagates plugin errors', () async {
      mockChannel((call) async => throw PlatformException(code: 'failed'));

      await expectLater(
        const ContactsService().fetchBirthdays(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
