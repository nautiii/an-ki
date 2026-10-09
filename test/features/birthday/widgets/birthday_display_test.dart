import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('formattedDate includes or omits the year', (tester) async {
    final context = await tester.pumpLocalizedContext();
    final birthday = BirthdayModel(
      id: '1',
      name: 'A',
      surname: 'B',
      date: DateTime(1990, 1, 10),
    );

    expect(birthday.formattedDate(context), '10 Janvier 1990');
    expect(birthday.formattedDate(context, includeYear: false), '10 Janvier');
  });
}
