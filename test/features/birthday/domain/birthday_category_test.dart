import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = BirthdayCategory(id: '1', name: 'A', icon: 1);

  group('equality', () {
    test('compares by value', () {
      const same = BirthdayCategory(id: '1', name: 'A', icon: 1);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      expect(const BirthdayCategory(id: '1', name: 'B', icon: 1), isNot(base));
      expect(const BirthdayCategory(id: '1', name: 'A', icon: 2), isNot(base));
      expect(const BirthdayCategory(id: '2', name: 'A', icon: 1), isNot(base));
    });
  });

  group('categoriesFrom', () {
    const family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
    const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 2);

    Birthday tagged(List<String> ids) => Birthday(
      id: 'b',
      name: 'Léa',
      surname: 'Martin',
      date: DateTime(1990),
      categories: ids,
    );

    test('keeps the order of the person', () {
      expect(tagged(['fri', 'fam']).categoriesFrom([family, friend]), [
        friend,
        family,
      ]);
    });

    test('skips unknown ids', () {
      expect(tagged(['gone', 'fam']).categoriesFrom([family]), [family]);
      expect(tagged(const []).categoriesFrom([family]), isEmpty);
    });
  });
}
