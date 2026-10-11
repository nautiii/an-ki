import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_providers.dart';

/// Notifications sans plugin.
class SilentNotificationService extends Fake implements NotificationService {
  @override
  void configure(NotificationStrings strings) {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleAll(List<ReminderNotification> reminders) async {}
}

/// Profil du compte `fake-uid` des faux dépôts.
const testProfile = UserProfile(
  id: 'fake-uid',
  name: 'Camille',
  surname: 'Durand',
  isDark: false,
  locale: 'fr',
);

extension AppTesterExt on WidgetTester {
  /// L'app entière, routeur compris, sur un écran de la taille du harnais
  /// (800×1200) : la session de [auth], l'empreinte de [biometrics], des
  /// données factices.
  Future<void> pumpApp({
    required FakeAuthRepository auth,
    FakeBiometricService? biometrics,
  }) {
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    return pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          biometricServiceProvider.overrideWithValue(
            biometrics ?? FakeBiometricService(),
          ),
          notificationServiceProvider.overrideWithValue(
            SilentNotificationService(),
          ),
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(stored: testProfile),
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

  /// Laisse le routeur choisir l'écran, puis écoule les fondus décalés de
  /// l'écran de connexion (jusqu'à 1,2 s).
  Future<void> settleApp() async {
    await pumpAndSettle();
    await pump(const Duration(seconds: 2));
    await pumpAndSettle();
  }

  /// Le routeur de l'app montée par [pumpApp].
  GoRouter get appRouter =>
      ProviderScope.containerOf(element(find.byType(App)))
          .read(appRouterProvider);
}
