/// Chemins des routes de l'application.
///
/// Dans `core/` pour que les features naviguent entre elles par chemin
/// (`context.go`, `context.push` de go_router), sans importer l'écran d'une
/// autre feature. Le routeur qui relie chaque chemin à son écran vit dans
/// `app/router/`, seule couche qui connaît toutes les features.
abstract final class AppRoutes {
  const AppRoutes._();

  /// Bienvenue, hors session : « Commencer » ou « J'ai déjà un compte ».
  static const String welcome = '/welcome';

  /// Connexion, ouverte par-dessus la bienvenue (`context.push`) ou seule
  /// quand l'empreinte verrouille l'app ; ses sous-pages s'empilent
  /// au-dessus d'elle.
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';

  /// Onglets de l'app connectée.
  static const String birthdays = '/birthdays';
  static const String scanner = '/scanner';

  /// Réglages, ouverts par-dessus un onglet (`context.push`).
  static const String settings = '/settings';

  /// Recherche d'anniversaires, ouverte par-dessus un onglet (`context.push`).
  static const String search = '/search';
}
