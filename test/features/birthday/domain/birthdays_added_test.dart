import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares every field', () {
    const added = BirthdaysAdded(count: 2, imported: true, first: false);

    expect(added, const BirthdaysAdded(count: 2, imported: true, first: false));
    expect(
      added.hashCode,
      const BirthdaysAdded(count: 2, imported: true, first: false).hashCode,
    );
    expect(
      added,
      isNot(const BirthdaysAdded(count: 3, imported: true, first: false)),
    );
    expect(
      added,
      isNot(const BirthdaysAdded(count: 2, imported: false, first: false)),
    );
    expect(
      added,
      isNot(const BirthdaysAdded(count: 2, imported: true, first: true)),
    );
  });
}
