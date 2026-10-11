import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_providers.dart';
import '../support/network_image_mock.dart';

/// Notifications sans plugin.
class _SilentNotificationService extends Fake implements NotificationService {
  @override
  void configure(NotificationStrings strings) {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleAll(List<ReminderNotification> reminders) async {}
}

/// Session qui n'arrive jamais : le démarrage reste en attente.
class _PendingAuthRepository extends FakeAuthRepository {
  @override
  Stream<User?> userChanges() => const Stream.empty();
}

const _profile = UserModel(
  id: 'fake-uid',
  name: 'Camille',
  surname: 'Durand',
  isDark: false,
  locale: 'fr',
);

void main() {
  /// Laisse la porte d'entrée choisir l'écran, puis écoule les fondus
  /// décalés de l'écran de connexion (jusqu'à 1,2 s).
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  /// L'app entière, sur un écran de la taille du harnais (800×1200).
  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeAuthRepository auth,
    FakeBiometricService? biometrics,
  }) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          biometricServiceProvider.overrideWithValue(
            biometrics ?? FakeBiometricService(),
          ),
          notificationServiceProvider.overrideWithValue(
            _SilentNotificationService(),
          ),
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(stored: _profile),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            FakeBirthdayRepository(),
          ),
          categoryRepositoryProvider.overrideWithValue(
            RecordingCategoryRepository(const []),
          ),
          bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
        ],
        child: const App(),
      ),
    );
  }

  testWidgets('waits for the session before choosing a screen', (tester) async {
    await pumpApp(tester, auth: _PendingAuthRepository());
    await tester.pump();

    expect(find.byType(AuthChoiceScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('shows the sign-in screen when nobody is signed in', (
    tester,
  ) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await settle(tester);

    expect(find.byType(AuthChoiceScreen), findsOneWidget);
  });

  testWidgets('opens the app for a restored session', (tester) async {
    await mockNetworkImages(() async {
      await pumpApp(tester, auth: FakeAuthRepository(user: MockUser()));
      await settle(tester);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(AuthChoiceScreen), findsNothing);
    });
  });

  testWidgets('keeps a restored session locked behind the fingerprint', (
    tester,
  ) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(user: MockUser()),
      // Empreinte configurée, mais l'utilisateur annule l'invite.
      biometrics: FakeBiometricService(
        available: true,
        token: 'tok',
        userId: 'fake-uid',
        authenticates: false,
      ),
    );
    await settle(tester);

    expect(find.byType(AuthChoiceScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('the fingerprint opens a locked session', (tester) async {
    await mockNetworkImages(() async {
      final auth = FakeAuthRepository(user: MockUser())
        ..biometricTokens['fake-uid'] = 'tok';
      await pumpApp(
        tester,
        auth: auth,
        biometrics: FakeBiometricService(
          available: true,
          token: 'tok',
          userId: 'fake-uid',
        ),
      );
      await settle(tester);

      expect(find.byType(MainShell), findsOneWidget);
    });
  });
}
