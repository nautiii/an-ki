import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('HomePage displays birthdays list', (tester) async {
    final birthdays = [
      BirthdayModel(
        id: '1',
        uid: 'fake-uid',
        name: 'Alice',
        surname: 'Wonderland',
        date: DateTime(1990, 5, 10),
        categories: [],
      ),
      BirthdayModel(
        id: '2',
        uid: 'fake-uid',
        name: 'Bob',
        surname: 'Builder',
        date: DateTime(1985, 10, 20),
        categories: [],
      ),
    ];

    await tester.pumpHarness(
      const HomePage(),
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProvider.overrideWith(FakeUserNotifier.new),
        birthdayProvider.overrideWith(
          () => FakeBirthdayNotifier(
            initialState: BirthdayState(birthdays: birthdays, isLoading: false),
          ),
        ),
        categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(find.text('Bob Builder'), findsOneWidget);
  });
}
