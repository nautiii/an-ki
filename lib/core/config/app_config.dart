import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration de l'app fixée à la compilation.
///
/// Lue depuis `--dart-define` (`--dart-define-from-file=secrets.json`) : les
/// secrets restent hors du code source.
class AppConfig {
  final String googleBooksApiKey;

  const AppConfig({required this.googleBooksApiKey});

  /// Valeurs passées par `--dart-define` à la compilation.
  factory AppConfig.fromEnvironment() => const AppConfig(
    googleBooksApiKey: String.fromEnvironment('GOOGLE_BOOKS_API_KEY'),
  );
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
