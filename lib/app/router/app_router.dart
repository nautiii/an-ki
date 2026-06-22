import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/home/main_screen.dart';
import 'package:flutter/material.dart';

/// Centralized route names for imperative navigation.
///
/// Use these constants instead of raw string literals so the route table and
/// every `Navigator.pushNamed` call stay in sync.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String auth = '/auth';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
}

/// The application route table, consumed by [MaterialApp.routes].
///
/// Lives in the `app/` layer (composition root): it is allowed to depend on
/// features, whereas `core/` must not.
abstract final class AppRouter {
  const AppRouter._();

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
    AppRoutes.auth: (_) => const AuthChoiceScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signup: (_) => const SignUpScreen(),
    AppRoutes.home: (_) => const AppInitializer(child: MainScreen()),
  };
}
