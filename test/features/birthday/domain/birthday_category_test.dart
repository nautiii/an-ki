import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = BirthdayCategory(id: '1', name: 'A', icon: 1);

  test('copyWith overrides selected fields and keeps the id', () {
    final copy = base.copyWith(name: 'B', icon: 2);

    expect(copy, const BirthdayCategory(id: '1', name: 'B', icon: 2));
    expect(base.copyWith(), base);
  });

  group('equality', () {
    test('compares by value', () {
      const same = BirthdayCategory(id: '1', name: 'A', icon: 1);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      expect(base.copyWith(name: 'Renamed'), isNot(base));
      expect(const BirthdayCategory(id: '2', name: 'A', icon: 1), isNot(base));
    });
  });
}
