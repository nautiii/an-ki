import 'package:an_ki/core/firebase_options.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/auth_choice_page.dart';
import 'package:an_ki/features/auth/login_page.dart';
import 'package:an_ki/features/auth/signup_page.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:an_ki/providers/auth_provider.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:an_ki/providers/theme_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BirthdayProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'An Ki',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home:
          authProvider.isAuthenticated
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
