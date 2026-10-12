import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('formattedDate follows the locale, with or without the year', (
    tester,
  ) async {
    final context = await tester.pumpLocalizedContext();
    final birthday = Birthday(
      id: '1',
      name: 'A',
      surname: 'B',
      date: BirthDate.fromDate(DateTime(1990, 1, 10)),
    );

    // Typographie française : mois en minuscules.
    expect(birthday.formattedDate(context), '10 janvier 1990');
    expect(birthday.formattedDate(context, includeYear: false), '10 janvier');
  });
}
