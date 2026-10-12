import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps only the day, month and year of a calendar date', () {
    expect(
      BirthDate.fromDate(DateTime(1990, 3, 12, 23, 59)),
      const BirthDate(year: 1990, month: 3, day: 12),
    );
  });

  test('compares by value', () {
    const date = BirthDate(year: 1990, month: 3, day: 12);

    expect(date, const BirthDate(year: 1990, month: 3, day: 12));
    expect(
      date.hashCode,
      const BirthDate(year: 1990, month: 3, day: 12).hashCode,
    );
    expect(date, isNot(const BirthDate(year: 1991, month: 3, day: 12)));
    expect(date, isNot(const BirthDate(year: 1990, month: 4, day: 12)));
    expect(date, isNot(const BirthDate(year: 1990, month: 3, day: 13)));
  });
}
