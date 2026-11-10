import 'dart:async';

import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_providers.dart';

/// Chemins de toutes les routes de [routes], sous-routes comprises.
Iterable<String> _paths(List<RouteBase> routes, [String parent = '']) sync* {
  for (final route in routes) {
    if (route is! GoRoute) continue;
    final path = route.path.startsWith('/')
        ? route.path
        : '$parent/${route.path}';
    yield path;
    yield* _paths(route.routes, path);
  }
}

void main() {
  test('Birthdays then Books, in the order of their tabs', () {
    expect(
      [for (final module in appModules) module.id],
      ['birthdays', 'books'],
    );
    expect(birthdaysModule.rootPath, AppRoutes.birthdays);
    expect(booksModule.rootPath, AppRoutes.books);
  });

  test('each module has its own id and its own root path', () {
    final ids = [for (final module in appModules) module.id];
    final roots = [for (final module in appModules) module.rootPath];

    expect(ids.toSet(), hasLength(ids.length));
    expect(roots.toSet(), hasLength(roots.length));
  });

  test('the floating bar holds every module tab', () {
    // Un 5e module demande l'onglet « Plus » (D13), pas encore construit.
    expect(appModules.length, lessThanOrEqualTo(maxModuleTabs));
  });

  test('a module always on is on by default', () {
    for (final module in appModules.where((module) => module.alwaysOn)) {
      expect(module.enabledByDefault, isTrue, reason: module.id);
    }
    expect(birthdaysModule.alwaysOn, isTrue);
    expect(booksModule.alwaysOn, isFalse);
  });

  test('every page of a tab sits under its module root', () {
    for (final module in appModules) {
      final paths = _paths(
        module.buildBranch(GlobalKey<NavigatorState>()).routes,
      ).toList();
      expect(paths.first, module.rootPath, reason: module.id);
      for (final path in paths) {
        expect(
          path == module.rootPath || path.startsWith('${module.rootPath}/'),
          isTrue,
          reason: '${module.id} : $path',
        );
      }
    }
  });

  test('each router gets branches of its own', () {
    // La clé du navigateur d'une branche ne sert qu'à un routeur.
    for (final module in appModules) {
      expect(
        module.buildBranch(GlobalKey<NavigatorState>()).navigatorKey,
        isNot(module.buildBranch(GlobalKey<NavigatorState>()).navigatorKey),
        reason: module.id,
      );
    }
  });

  test('Birthdays keeps the reminders in sync while it is on', () {
    expect(birthdaysModule.effects, [reminderSyncProvider]);
    expect(booksModule.effects, isEmpty);
  });

  test('names and describes each module', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));

    expect(birthdaysModule.name(l10n), 'Anniversaires');
    expect(booksModule.name(l10n), 'Livres');
    expect(
      birthdaysModule.description(l10n),
      'Qui fête quoi, et quand le souhaiter',
    );
    expect(
      booksModule.description(l10n),
      'Vos séries : le dernier tome, le prochain et sa date de sortie',
    );
  });

  test('every module says how its data leaves with the account', () {
    for (final module in appModules) {
      expect(module.data, isNotNull, reason: module.id);
    }
    // Les anniversaires suivent un invité par GuestMerge, et leurs doublons.
    expect(birthdaysModule.data?.guestTransfer, isNull);
    expect(booksModule.data?.guestTransfer, isNotNull);
  });

  group('active modules', () {
    late _Profiles profiles;
    late ProviderContainer container;

    /// Connecté comme [uid] (null : personne). Relu aussitôt : le profil
    /// s'abonne à son flux avant la première émission du test.
    void signIn(String? uid) {
      container.read(_uid.notifier).set(uid);
      container.read(activeModulesProvider);
    }

    List<String>? activeIds() => container
        .read(activeModulesProvider)
        ?.map((module) => module.id)
        .toList();

    List<String> runningIds() => [
      for (final module in container.read(runningModulesProvider)) module.id,
    ];

    setUp(() {
      profiles = _Profiles();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          currentUidProvider.overrideWith((ref) => ref.watch(_uid)),
          userRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      container
        ..listen(activeModulesProvider, (_, _) {})
        ..listen(runningModulesProvider, (_, _) {});
    });

    test('signed out, the defaults: Birthdays only', () {
      expect(activeIds(), ['birthdays']);
      expect(runningIds(), ['birthdays']);
    });

    test('unknown while the profile loads, Birthdays running meanwhile', () {
      signIn('u1');

      expect(activeIds(), isNull);
      expect(runningIds(), ['birthdays']);
    });

    test('follow the choices of the loaded profile', () async {
      signIn('u1');
      await profiles.emit(_profile('u1', {'books': true}));

      expect(activeIds(), ['birthdays', 'books']);
      expect(runningIds(), ['birthdays', 'books']);

      await profiles.emit(_profile('u1', {'books': false}));
      expect(activeIds(), ['birthdays']);
    });

    test('an old profile without choices has Birthdays only', () async {
      signIn('u1');
      await profiles.emit(_profile('u1', const {}));

      expect(activeIds(), ['birthdays']);
    });

    test('the defaults while the profile does not exist yet', () async {
      signIn('u1');
      await profiles.emit(null, uid: 'u1');

      expect(activeIds(), ['birthdays']);
    });

    test('the defaults when the profile cannot be read', () async {
      signIn('u1');
      await profiles.fail('u1');

      expect(activeIds(), ['birthdays']);
    });

    test('the profile of the previous account never decides', () async {
      signIn('u1');
      await profiles.emit(_profile('u1', {'books': true}));

      signIn('u2');

      expect(activeIds(), isNull);
      await profiles.emit(_profile('u2', const {}));
      expect(activeIds(), ['birthdays']);
    });

    test('a profile change that keeps the modules notifies no one', () async {
      signIn('u1');
      await profiles.emit(_profile('u1', {'books': true}));
      var notified = 0;
      container.listen(activeModulesProvider, (_, _) => notified++);

      await profiles.emit(_profile('u1', {'books': true}, pseudo: 'Cam'));
      await profiles.emit(_profile('u1', {'books': true, 'films': true}));

      expect(notified, 0);
      await profiles.emit(_profile('u1', {'books': false}));
      expect(notified, 1);
    });
  });
}

/// Session du test : l'uid connecté, ou null.
final _uid = NotifierProvider<_Uid, String?>(_Uid.new);

class _Uid extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? uid) => state = uid;
}

UserProfile _profile(String uid, Map<String, bool> modules, {String? pseudo}) =>
    UserProfile(
      id: uid,
      name: 'Camille',
      surname: '',
      pseudo: pseudo,
      moduleChoices: modules,
    );

/// Profils en temps réel, émis à la main, un flux par compte.
class _Profiles extends FakeUserRepository {
  final _streams = <String, StreamController<UserProfile?>>{};

  StreamController<UserProfile?> _of(String uid) =>
      _streams.putIfAbsent(uid, StreamController<UserProfile?>.broadcast);

  @override
  Stream<UserProfile?> watchUser(String uid) => _of(uid).stream;

  /// Émet [profile] pour son compte (ou [uid] pour un document absent).
  Future<void> emit(UserProfile? profile, {String? uid}) async {
    _of(uid ?? profile!.id).add(profile);
    await pumpEventQueue();
  }

  Future<void> fail(String uid) async {
    _of(uid).addError(Exception('permission denied'));
    await pumpEventQueue();
  }
}
