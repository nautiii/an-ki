import 'dart:async';

import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_providers.dart';

/// Notifications sans plugin : aucun toucher, sauf ceux que le test envoie
/// par [tap] ou donne comme [launch]. L'autorisation vaut [access] (accordée
/// par défaut, donc sans proposition des rappels) ; une demande renvoie
/// [answer] et la retient. Relève les demandes et les ouvertures des
/// réglages.
class SilentNotificationService extends Fake implements NotificationService {
  SilentNotificationService({
    this.launch,
    NotificationAccess access = NotificationAccess.granted,
    this.answer = NotificationAccess.granted,
  }) : current = access;

  /// Toucher qui aurait lancé l'app.
  final NotificationTap? launch;

  /// Autorisation actuelle, telle que le téléphone la dirait.
  NotificationAccess current;

  /// Réponse à la prochaine demande d'autorisation.
  NotificationAccess answer;

  int requests = 0;
  int settingsOpened = 0;

  final _taps = StreamController<NotificationTap>.broadcast();

  /// Simule un toucher pendant que l'app tourne.
  void tap(NotificationTap tap) => _taps.add(tap);

  @override
  void configure(NotificationStrings strings) {}

  @override
  Future<NotificationAccess> access() async => current;

  @override
  Future<NotificationAccess> requestAccess() async {
    requests++;
    // Le blocage ne se voit qu'à la demande : la lecture dit « refusée ».
    current = answer == NotificationAccess.blocked
        ? NotificationAccess.denied
        : answer;
    return answer;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> scheduleAll(List<ReminderNotification> reminders) async {}

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<NotificationTap?> launchTap() async => launch;
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
  /// données factices (le carnet [birthdays], vide par défaut), des
  /// notifications, un partage et un répertoire simulés ([notifications],
  /// [share], [contacts]).
  Future<void> pumpApp({
    required FakeAuthRepository auth,
    FakeBiometricService? biometrics,
    List<Birthday> birthdays = const [],
    SilentNotificationService? notifications,
    FakeShareService? share,
    FakeContactsService? contacts,
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
            notifications ?? SilentNotificationService(),
          ),
          shareServiceProvider.overrideWithValue(share ?? FakeShareService()),
          contactsServiceProvider.overrideWithValue(
            contacts ?? FakeContactsService(),
          ),
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(stored: testProfile),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(initial: birthdays),
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

  /// Laisse le routeur choisir l'écran, puis écoule les fondus décalés des
  /// formulaires de connexion et d'inscription (jusqu'à 1 s).
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
