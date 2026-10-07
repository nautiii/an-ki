import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time environment, selected via `--dart-define=ENV=dev|staging|prod`.
enum AppEnvironment { dev, staging, prod }

/// Centralized, build-time application configuration.
///
/// Reads from `--dart-define` so secrets and per-environment values stay out of
/// source. Native build flavors (Android product flavors / iOS schemes) can be
/// layered on top later and simply pass matching `--dart-define`s.
class AppConfig {
  final AppEnvironment environment;
  final String googleBooksApiKey;

  const AppConfig({required this.environment, required this.googleBooksApiKey});

  /// Builds the config from compile-time `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('ENV', defaultValue: 'prod');
    const apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');
    return AppConfig(
      environment: _parseEnvironment(env),
      googleBooksApiKey: apiKey,
    );
  }

  bool get isProd => environment == AppEnvironment.prod;
  bool get isDev => environment == AppEnvironment.dev;

  static AppEnvironment _parseEnvironment(String value) {
    switch (value.toLowerCase()) {
      case 'dev':
        return AppEnvironment.dev;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.prod;
    }
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
