import 'package:an_ki/app/bootstrap/app_locale.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/providers/device_locales_provider.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Racine de l'app : thème, langue et routeur ([appRouterProvider]), qui
/// choisit l'écran selon l'accès.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Langue du téléphone changée pendant que l'app tourne : l'app (et ses
  /// rappels, s'ils la suivent) passe à la nouvelle.
  @override
  void didChangeLocales(List<Locale>? locales) =>
      ref.invalidate(deviceLocalesProvider);

  @override
  Widget build(BuildContext context) {
    // Garde en vie les effets des modules actifs (la synchro des rappels pour
    // Anniversaires) : un provider que personne n'écoute est mis en pause.
    for (final module in ref.watch(activeModulesProvider)) {
      for (final effect in module.effects) {
        ref.watch(effect);
      }
    }
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(appLocaleProvider);

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
