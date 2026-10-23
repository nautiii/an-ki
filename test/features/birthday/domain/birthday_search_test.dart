import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _person(
  String name,
  String surname, [
  List<String> categories = const [],
]) => Birthday(
  id: name,
  name: name,
  surname: surname,
  date: BirthDate.fromDate(DateTime(1990)),
  categories: categories,
);

void main() {
  final lea = _person('Léa', 'Martin', ['friend', 'family']);
  final hugo = _person('Hugo', 'Bernard', ['colleague']);
  final people = [lea, hugo];

  test('matches first name, last name or full name, ignoring case', () {
    expect(people.matching('léa'), [lea]);
    expect(people.matching('BERN'), [hugo]);
    expect(people.matching('léa mar'), [lea]);
    expect(people.matching(' hugo '), [hugo]);
  });

  test('finds a person known by a single name', () {
    final mamie = _person('Mamie', '');

    expect([...people, mamie].matching('mamie'), [mamie]);
  });

  test('keeps everyone for an empty query', () {
    expect(people.matching(''), people);
  });

  test('requires every selected category', () {
    expect(people.matching('', categoryIds: ['friend']), [lea]);
    expect(people.matching('', categoryIds: ['friend', 'family']), [lea]);
    expect(people.matching('', categoryIds: ['friend', 'colleague']), isEmpty);
  });

  test('combines the query and the categories', () {
    expect(people.matching('hugo', categoryIds: ['friend']), isEmpty);
  });

  test('ignores accents, both ways', () {
    final helene = _person('Helene', 'Dupre');

    expect(people.matching('lea'), [lea]);
    expect(people.matching('LÉA'), [lea]);
    expect([helene].matching('hélène dupré'), [helene]);
  });

  group('nameMatch', () {
    test('finds the letters, ignoring case and accents', () {
      expect(lea.nameMatch('lea'), (start: 0, end: 3));
      expect(lea.nameMatch('MART'), (start: 4, end: 8));
      expect(lea.nameMatch('a m'), (start: 2, end: 5));
    });

    test('maps a trimmed query back onto the name', () {
      expect(lea.nameMatch('  martin '), (start: 4, end: 10));
    });

    test('prefers the start of a word, else the first match', () {
      final emma = _person('Emma', 'Martin');
      final anne = _person('Jeanne', 'Anne-Marie');

      expect(emma.nameMatch('ma'), (start: 5, end: 7));
      expect(emma.nameMatch('m'), (start: 5, end: 6));
      expect(anne.nameMatch('mar'), (start: 12, end: 15));
      expect(_person('Hannah', '').nameMatch('an'), (start: 1, end: 3));
    });

    test('keeps a combining accent with its letter', () {
      // « Léa » saisie en forme décomposée : « e » puis l'accent combinant.
      final decomposed = _person('Léa', '');

      expect(decomposed.nameMatch('le'), (start: 0, end: 3));
      expect(decomposed.nameMatch('a'), (start: 3, end: 4));
    });

    test('spells ligatures and matches curly apostrophes', () {
      expect(_person('Chloé', 'Lœwen').nameMatch('loew'), (start: 6, end: 9));
      expect(_person('Marco', 'D’Amico').nameMatch("d'am"), (
        start: 6,
        end: 10,
      ));
    });

    test('is null for an empty query or no match', () {
      expect(lea.nameMatch(''), isNull);
      expect(lea.nameMatch('   '), isNull);
      expect(lea.nameMatch('hugo'), isNull);
    });

    test('agrees with the filter', () {
      for (final query in ['lé', 'MARTIN', 'a m', 'xyz', 'ber']) {
        expect(people.matching(query), [
          for (final person in people)
            if (person.nameMatch(query) != null) person,
        ], reason: query);
      }
    });
  });
}
