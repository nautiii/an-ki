import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Racine de l'app : thème, langue et routeur ([appRouterProvider]), qui
/// choisit l'écran selon l'accès.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Active la synchro des rappels pour toute la vie de l'app : un provider
    // que personne n'écoute est mis en pause.
    ref.watch(reminderSyncProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'AnKi',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
