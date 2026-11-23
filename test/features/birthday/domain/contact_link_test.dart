import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _lea = ContactLink(number: '0611111111', contactName: 'Léa Martin');
const _hugo = ContactLink(number: '0622222222', contactName: 'Hugo');
const _mamie = ContactLink(number: '0133333333', contactName: '');

void main() {
  test('links are equal by value', () {
    expect(
      const ContactLink(number: '0611111111', contactName: 'Léa Martin'),
      _lea,
    );
    expect(
      const ContactLink(
        number: '0611111111',
        contactName: 'Léa Martin',
      ).hashCode,
      _lea.hashCode,
    );
    expect(_lea, isNot(_hugo));
  });

  group('takeOverContactLinks', () {
    test('a moved record keeps its link under the same id', () {
      expect(
        takeOverContactLinks(
          guest: const {'b1': _lea},
          target: const {},
          keptIds: const {'b1': 'b1'},
        ),
        {'b1': _lea},
      );
    });

    test('a duplicate passes its link to the record kept', () {
      expect(
        takeOverContactLinks(
          guest: const {'b2': _lea},
          target: const {'t1': _hugo},
          keptIds: const {'b2': 't9'},
        ),
        {'t1': _hugo, 't9': _lea},
      );
    });

    test('the account keeps its own link on a record already linked', () {
      expect(
        takeOverContactLinks(
          guest: const {'b2': _lea},
          target: const {'t1': _hugo},
          keptIds: const {'b2': 't1'},
        ),
        {'t1': _hugo},
      );
    });

    test('two guest duplicates of one person: the first link stays', () {
      expect(
        takeOverContactLinks(
          guest: const {'b1': _lea, 'b2': _mamie},
          target: const {},
          keptIds: const {'b1': 'b1', 'b2': 'b1'},
        ),
        {'b1': _lea},
      );
    });

    test('a moved record keeps its own link, whatever the stored order', () {
      expect(
        takeOverContactLinks(
          guest: const {'b2': _mamie, 'b1': _lea},
          target: const {},
          keptIds: const {'b1': 'b1', 'b2': 'b1'},
        ),
        {'b1': _lea},
      );
    });

    test('a guest record the plan does not keep loses its link', () {
      expect(
        takeOverContactLinks(
          guest: const {'gone': _lea},
          target: const {},
          keptIds: const {},
        ),
        isEmpty,
      );
    });
  });
}
