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

  /// L'étagère, racine de l'onglet Livres ; les pages du module vivent sous
  /// ce chemin, que la redirection des modules reconnaît.
  static const String books = '/books';

  /// Scanner d'ISBN, poussé par-dessus l'onglet (`context.push`) : la caméra
  /// ne tourne que tant qu'il est ouvert.
  static const String booksScan = '/books/scan';

  /// Tomes « à classer », poussés par-dessus l'onglet.
  static const String booksInbox = '/books/inbox';

  /// Page d'une série, poussée par-dessus l'onglet : le motif de la route ;
  /// [series] donne le chemin d'une série.
  static const String seriesPattern = '/books/series/:id';

  static String series(String seriesId) =>
      '/books/series/${Uri.encodeComponent(seriesId)}';

  /// Réglages, ouverts par-dessus un onglet (`context.push`).
  static const String settings = '/settings';

  /// Modules que l'utilisateur active, ouverts par-dessus les réglages
  /// (`context.push`).
  static const String modules = '/settings/modules';

  /// Recherche d'anniversaires, ouverte par-dessus un onglet (`context.push`).
  static const String search = '/search';

  /// Recherche préfiltrée sur le groupe [categoryId], passé en paramètre
  /// [searchCategoryParam].
  static String searchInCategory(String categoryId) => Uri(
    path: search,
    queryParameters: {searchCategoryParam: categoryId},
  ).toString();

  static const String searchCategoryParam = 'category';

  /// Import des anniversaires du répertoire, ouvert par-dessus l'accueil vide
  /// ou les réglages (`context.push`).
  static const String contactImport = '/import';

  /// Groupes de l'utilisateur, ouverts par-dessus les réglages
  /// (`context.push`).
  static const String groups = '/groups';

  /// Page d'une personne, ouverte par-dessus un onglet (`context.push`) :
  /// le motif de la route ; [person] donne le chemin d'un anniversaire.
  static const String personPattern = '/person/:id';

  static String person(String birthdayId) =>
      '/person/${Uri.encodeComponent(birthdayId)}';
}
