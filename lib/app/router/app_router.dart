import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/app/bootstrap/reminder_prompt.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/auth/screens/welcome_screen.dart';
import 'package:an_ki/features/birthday/screens/birthday_search_screen.dart';
import 'package:an_ki/features/birthday/screens/contact_import_screen.dart';
import 'package:an_ki/features/birthday/screens/groups_screen.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Écran neutre du démarrage, tant que l'accès n'est pas connu.
const String _startup = '/';

/// Routeur de l'application : chaque chemin d'[AppRoutes] vers son écran, les
/// onglets des modules ([appModulesProvider]), et les redirections qui suivent
/// l'accès ([authAccessProvider]).
///
/// Vit dans la couche `app/` (composition root) : il a le droit de dépendre
/// des features, contrairement à `core/`. Créé une seule fois : un changement
/// d'accès réévalue les redirections sans recréer le routeur.
final appRouterProvider = Provider<GoRouter>((ref) {
  final modules = ref.read(appModulesProvider);
  final access = ValueNotifier<AuthAccess?>(null);
  ref.listen(
    authAccessProvider,
    (_, next) => access.value = next,
    fireImmediately: true,
  );
  final router = GoRouter(
    initialLocation: AppRoutes.birthdays,
    refreshListenable: access,
    redirect: (_, state) => accessRedirect(access.value, state.matchedLocation),
    routes: [
      GoRoute(path: _startup, builder: (_, _) => const _StartupScreen()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, _) => const AuthChoiceScreen(),
        // Segments de AppRoutes.login et AppRoutes.signup.
        routes: [
          GoRoute(path: 'login', builder: (_, _) => const LoginScreen()),
          GoRoute(path: 'signup', builder: (_, _) => const SignUpScreen()),
        ],
      ),
      StatefulShellRoute(
        builder: (_, _, shell) => AppInitializer(
          child: ReminderPrompt(child: MainShell(navigationShell: shell)),
        ),
        navigatorContainerBuilder: (_, shell, branches) =>
            ShellBranches(currentIndex: shell.currentIndex, children: branches),
        // Une branche par module du registre, dans son ordre : l'index d'une
        // branche est la place de son module dans le registre.
        branches: [for (final module in modules) module.buildBranch()],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const _SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, state) => BirthdaySearchScreen(
          initialCategoryId:
              state.uri.queryParameters[AppRoutes.searchCategoryParam],
        ),
      ),
      GoRoute(
        path: AppRoutes.contactImport,
        builder: (_, _) => const ContactImportScreen(),
      ),
      GoRoute(path: AppRoutes.groups, builder: (_, _) => const GroupsScreen()),
      GoRoute(
        path: AppRoutes.personPattern,
        builder: (_, state) =>
            PersonScreen(birthdayId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    access.dispose();
  });
  return router;
});

/// Où l'accès envoie [location] ; null pour y rester.
///
/// Accès inconnu (démarrage) : l'écran neutre. Personne de connecté : la
/// bienvenue, et la connexion ouverte par-dessus. App verrouillée : la
/// connexion seule, jamais la bienvenue, dont « Commencer » remplacerait la
/// session du compte. Accès accordé : l'app, plus jamais la bienvenue ni la
/// connexion ; les écrans ouverts par-dessus restent ouverts tant que l'accès
/// ne change pas.
String? accessRedirect(AuthAccess? access, String location) {
  final inAuth =
      location == AppRoutes.auth || location.startsWith('${AppRoutes.auth}/');
  final atWelcome = location == AppRoutes.welcome;
  return switch (access) {
    null => location == _startup ? null : _startup,
    AuthAccess.signedOut => inAuth || atWelcome ? null : AppRoutes.welcome,
    AuthAccess.locked => inAuth ? null : AppRoutes.auth,
    AuthAccess.granted =>
      inAuth || atWelcome || location == _startup ? AppRoutes.birthdays : null,
  };
}

/// Réglages, avec la section de chaque module actif entre les préférences et
/// la sécurité.
class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsScreen(
    moduleSections: [
      for (final module in ref.watch(activeModulesProvider))
        ?module.settingsSection,
    ],
  );
}

/// Démarrage : session et verrou biométrique pas encore connus (quelques
/// millisecondes). Un fond neutre, plutôt que la bienvenue qui clignoterait
/// avant l'app ou le verrou.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
