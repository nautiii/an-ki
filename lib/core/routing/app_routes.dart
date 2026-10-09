/// Chemins des routes nommées de l'application.
///
/// Dans `core/` pour que les features naviguent entre elles par chemin, sans
/// importer l'écran d'une autre feature. La table qui relie chaque chemin à
/// son écran vit dans `app/router/`, seule couche qui connaît toutes les
/// features ; le passage à go_router (décision D9) reprendra ces chemins.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String auth = '/auth';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String settings = '/settings';
}
