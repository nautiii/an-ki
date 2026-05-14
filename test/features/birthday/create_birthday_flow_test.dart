import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HomePage opens the create birthday page from the search bar add button',
    (WidgetTester tester) async {
      final birthdayNotifierInstance = FakeBirthdayNotifier();

      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _TestApp(birthdayNotifierInstance: birthdayNotifierInstance),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Nouvel anniversaire'), findsOneWidget);
    },
  );

  testWidgets('Create birthday flow submits a new birthday to the provider', (
    WidgetTester tester,
  ) async {
    final birthdayNotifierInstance = FakeBirthdayNotifier();

    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _TestApp(birthdayNotifierInstance: birthdayNotifierInstance),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Thomas');
    await tester.enterText(find.byType(TextFormField).last, 'Leroy');

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(birthdayNotifierInstance.createdInputs, hasLength(1));
    expect(birthdayNotifierInstance.createdInputs.single.name, 'Thomas');
    expect(birthdayNotifierInstance.createdInputs.single.surname, 'Leroy');
    // Categories might be empty or have a default one.
    // In our implementation it defaults to 'friend' if we had one, but we use IDs now.
    expect(find.text('Nouvel anniversaire'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.birthdayNotifierInstance});

  final FakeBirthdayNotifier birthdayNotifierInstance;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProvider.overrideWith(
          () => FakeUserNotifier(
            initialState: UserState(
              user: const UserModel(id: '1', name: 'Marie', surname: 'Martin'),
            ),
          ),
        ),
        birthdayProvider.overrideWith(() => birthdayNotifierInstance),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('fr'),
        home: HomePage(),
      ),
    );
  }
}
