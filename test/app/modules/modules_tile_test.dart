import 'package:an_ki/app/modules/modules_tile.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

void main() {
  /// La ligne, connectée au profil aux choix [modules].
  Future<void> pumpTile(
    WidgetTester tester, {
    Map<String, bool> modules = const {},
  }) => tester.pumpHarness(
    const ModulesTile(),
    overrides: [
      currentUidProvider.overrideWithValue('u1'),
      userRepositoryProvider.overrideWithValue(
        RecordingUserRepository(
          stored: UserProfile(
            id: 'u1',
            name: 'Camille',
            surname: '',
            moduleChoices: modules,
          ),
        ),
      ),
    ],
    routes: {
      AppRoutes.modules: (_) => const Scaffold(body: Text('Écran modules')),
    },
  );

  testWidgets('counts the active modules', (tester) async {
    await pumpTile(tester);
    await tester.pumpAndSettle();

    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('1 actif'), findsOneWidget);
  });

  testWidgets('counts Books once turned on', (tester) async {
    await pumpTile(tester, modules: const {'books': true});
    await tester.pumpAndSettle();

    expect(find.text('2 actifs'), findsOneWidget);
  });

  testWidgets('says no count while the profile loads', (tester) async {
    await tester.pumpHarness(
      const ModulesTile(),
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        userProfileProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    await tester.pump();

    expect(find.text('Modules'), findsOneWidget);
    expect(find.textContaining('actif'), findsNothing);
  });

  testWidgets('opens the Modules screen', (tester) async {
    await pumpTile(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modules'));
    await tester.pumpAndSettle();

    expect(find.text('Écran modules'), findsOneWidget);
  });
}
