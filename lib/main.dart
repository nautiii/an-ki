import 'package:an_ki/core/firebase_options.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/auth_choice_page.dart';
import 'package:an_ki/features/auth/login_page.dart';
import 'package:an_ki/features/auth/signup_page.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'AnKi',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('fr'),
      home:
          authState.isAuthenticated
              ? const AppInitializer(child: HomePage())
              : const AuthChoicePage(),
      routes: {
        '/auth': (context) => const AuthChoicePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const AppInitializer(child: HomePage()),
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
