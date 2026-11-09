import 'dart:async';

import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/providers/device_locales_provider.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/books/data/book_repository.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
  Future<void> scheduleAll(
    List<ReminderNotification> reminders, {
    required NotificationStrings strings,
  }) async {}

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
  locale: 'fr',
);

/// [testProfile] avec le module Livres activé : la barre du bas et ses deux
/// onglets.
const booksOnProfile = UserProfile(
  id: 'fake-uid',
  name: 'Camille',
  surname: 'Durand',
  locale: 'fr',
  moduleChoices: {'books': true},
);

extension AppTesterExt on WidgetTester {
  /// L'app entière, routeur compris, sur un écran de la taille du harnais
  /// (800×1200) : la session de [auth], l'empreinte de [biometrics], des
  /// données factices (le carnet [birthdays], vide par défaut), des
  /// notifications, un partage, un répertoire et des réglages d'appareil
  /// simulés ([notifications], [share], [contacts], [deviceSettings]).
  /// [overrides] s'ajoutent à ceux du harnais, pour des providers qu'il ne
  /// remplace pas déjà (le registre des modules, par exemple). [profile] est
  /// le profil stocké du compte (par défaut [testProfile]) : ses choix de
  /// modules décident des onglets. [users] remplace le dépôt de profils
  /// (un profil qui tarde, par exemple).
  Future<void> pumpApp({
    required FakeAuthRepository auth,
    UserProfile profile = testProfile,
    UserRepository? users,
    FakeBiometricService? biometrics,
    List<Birthday> birthdays = const [],
    SilentNotificationService? notifications,
    FakeShareService? share,
    FakeContactsService? contacts,
    FakeDeviceSettings? deviceSettings,
    Locale deviceLocale = const Locale('fr', 'FR'),
    List<Override> overrides = const [],
  }) {
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    // Téléphone en français de France par défaut (voir pumpHarness) : l'app
    // en prend la langue tant que le profil n'en choisit pas une.
    // Un test change la langue du téléphone avec
    // `platformDispatcher.localesTestValue`, que l'app relit.
    platformDispatcher
      ..localeTestValue = deviceLocale
      ..localesTestValue = [deviceLocale];
    addTearDown(platformDispatcher.clearLocaleTestValue);
    addTearDown(platformDispatcher.clearLocalesTestValue);
    return pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          deviceLocalesProvider.overrideWith(
            (ref) => platformDispatcher.locales,
          ),
          authRepositoryProvider.overrideWithValue(auth),
          biometricServiceProvider.overrideWithValue(
            biometrics ?? FakeBiometricService(),
          ),
          notificationServiceProvider.overrideWithValue(
            notifications ?? SilentNotificationService(),
          ),
          localizedNotificationStrings,
          ...moduleDataHooks,
          shareServiceProvider.overrideWithValue(share ?? FakeShareService()),
          contactsServiceProvider.overrideWithValue(
            contacts ?? FakeContactsService(),
          ),
          deviceSettingsProvider.overrideWithValue(
            deviceSettings ?? FakeDeviceSettings(),
          ),
          userRepositoryProvider.overrideWithValue(
            users ?? RecordingUserRepository(stored: profile),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(initial: birthdays),
          ),
          categoryRepositoryProvider.overrideWithValue(
            RecordingCategoryRepository(const []),
          ),
          bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
          reminderPreferencesRepositoryProvider.overrideWithValue(
            RecordingReminderPreferencesRepository(),
          ),
          ...overrides,
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
