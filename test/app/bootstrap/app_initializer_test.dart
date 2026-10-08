import 'dart:async';

import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

/// Dépôt dont le profil n'arrive que lorsque le test le décide.
class _PendingUserRepository extends FakeUserRepository {
  final profile = StreamController<UserModel?>();

  @override
  Stream<UserModel?> watchUser(String uid) => profile.stream;

  Future<void> close() => profile.close();
}

const _profile = UserModel(
  id: 'u1',
  name: 'Camille',
  surname: 'Durand',
  isDark: false,
  locale: 'fr',
);

void main() {
  Future<void> pumpInitializer(
    WidgetTester tester, {
    required FakeUserRepository users,
    String? displayName = 'Léa Martin',
    bool anonymous = false,
    SignUpNames? typedNames,
  }) => tester.pumpHarness(
    const AppInitializer(child: _Child()),
    overrides: [
      authProvider.overrideWith(
        () => FakeAuthNotifier(
          initialState: AuthState(
            user: fam.MockUser(
              uid: 'u1',
              isAnonymous: anonymous,
              displayName: displayName,
            ),
          ),
        ),
      ),
      userRepositoryProvider.overrideWithValue(users),
      if (typedNames != null)
        signUpNamesProvider.overrideWithBuild((ref, notifier) => typedNames),
    ],
  );

  testWidgets('waits for the first profile, then shows the app', (
    tester,
  ) async {
    final users = _PendingUserRepository();
    addTearDown(users.close);
    await pumpInitializer(tester, users: users);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    users.profile.add(_profile);
    await tester.pumpAndSettle();

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('creates a guest profile for an anonymous account', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    await pumpInitializer(
      tester,
      users: users,
      displayName: '',
      anonymous: true,
    );
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Invité');
    expect(users.created.single.id, 'u1');
    expect(find.text('Child ready'), findsOneWidget);
  });

  testWidgets('splits the Google display name', (tester) async {
    final users = RecordingUserRepository();
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Léa');
    expect(users.created.single.surname, 'Martin');
  });

  testWidgets('keeps the names typed at sign-up, then forgets them', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    await pumpInitializer(
      tester,
      users: users,
      displayName: 'Jean Pierre Dupont',
      typedNames: (name: 'Jean Pierre', surname: 'Dupont'),
    );
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Jean Pierre');
    expect(users.created.single.surname, 'Dupont');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppInitializer)),
    );
    expect(container.read(signUpNamesProvider), isNull);
  });

  testWidgets('never creates a profile that already exists', (tester) async {
    final users = RecordingUserRepository(stored: _profile);
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created, isEmpty);
    expect(find.text('Child ready'), findsOneWidget);
  });
}

class _Child extends StatelessWidget {
  const _Child();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
