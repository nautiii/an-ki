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
  date: DateTime(1990),
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
}
