import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/home/main_screen.dart';
import 'package:flutter/material.dart';

/// Noms de routes centralisés pour la navigation impérative.
///
/// On utilise ces constantes plutôt que des chaînes brutes, pour que la table
/// de routes et chaque appel `Navigator.pushNamed` restent synchronisés.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String auth = '/auth';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
}

/// Table de routes de l'application, consommée par [MaterialApp.routes].
///
/// Vit dans la couche `app/` (composition root) : elle a le droit de dépendre
/// des features, contrairement à `core/`.
abstract final class AppRouter {
  const AppRouter._();

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
    AppRoutes.auth: (_) => const AuthChoiceScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signup: (_) => const SignUpScreen(),
    AppRoutes.home: (_) => const AppInitializer(child: MainScreen()),
  };
}
