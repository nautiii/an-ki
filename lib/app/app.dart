import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Active la synchro des rappels pour toute la vie de l'app : un provider
    // que personne n'écoute est mis en pause.
    ref.watch(reminderSyncProvider);
    // L'accès change (connexion, déconnexion, verrouillage) : l'écran racine
    // aussi. Les écrans poussés par-dessus (connexion par e-mail,
    // inscription, réglages) n'ont plus lieu d'être.
    ref.listen(authAccessProvider, (previous, next) {
      if (previous != null && previous != next) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
    final themeMode = ref.watch(themeProvider);
    final access = ref.watch(authAccessProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'AnKi',
      navigatorKey: _navigatorKey,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: switch (access) {
        AuthAccess.granted => const AppInitializer(child: MainShell()),
        AuthAccess.signedOut || AuthAccess.locked => const AuthChoiceScreen(),
        null => const _StartupScreen(),
      },
      routes: AppRouter.routes,
    );
  }
}

/// Démarrage : session et verrou biométrique pas encore connus (quelques
/// millisecondes). Un fond neutre, plutôt que l'écran de connexion qui
/// clignoterait avant l'app ou le verrou.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
