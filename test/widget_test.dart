import 'package:an_ki/core/app_initializer.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_providers.dart';

void main() {
  testWidgets('AppInitializer loads the user after the first frame', (
    WidgetTester tester,
  ) async {
    final userProviderInstance = FakeUserProvider();
    userProviderInstance.preparePendingLoad();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthProvider()),
          userProvider.overrideWith((ref) => userProviderInstance),
          birthdayProvider.overrideWith((ref) => FakeBirthdayProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('fr'),
          home: AppInitializer(child: TestChild()),
        ),
      ),
    );

    // Initial state: User is null, not loading.
    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Now let's simulate being authenticated
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppInitializer)),
    );
    // We can't easily set the user on FakeAuthProvider if it's already created.
    // Actually, we can use ref.read(authProvider.notifier).state = ...
    // But StateNotifier.state is protected.
    // I should add a helper to FakeAuthProvider.
  });
}

class TestChild extends StatelessWidget {
  const TestChild({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
