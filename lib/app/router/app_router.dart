import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/user/screens/settings_screen.dart';
import 'package:flutter/material.dart';

/// Table de routes de l'application, consommée par [MaterialApp.routes] :
/// chaque chemin d'[AppRoutes] vers son écran.
///
/// Vit dans la couche `app/` (composition root) : elle a le droit de dépendre
/// des features, contrairement à `core/`.
abstract final class AppRouter {
  const AppRouter._();

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
    AppRoutes.auth: (_) => const AuthChoiceScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signup: (_) => const SignUpScreen(),
    AppRoutes.home: (_) => const AppInitializer(child: MainShell()),
    AppRoutes.settings: (_) => const SettingsScreen(),
  };
}
