import 'package:an_ki/app/modules/app_module.dart';

/// Ids des modules actifs, dans l'ordre du [registry] : un module toujours
/// actif l'est ; sinon le choix explicite de l'utilisateur ([choices], par
/// id) ; sinon son réglage par défaut. Un choix pour un id que le registre
/// ne connaît pas (module retiré, version plus récente) est ignoré.
Set<String> activeModuleIds(
  List<AppModule> registry,
  Map<String, bool> choices,
) => {
  for (final module in registry)
    if (module.alwaysOn || (choices[module.id] ?? module.enabledByDefault))
      module.id,
};

/// Redirection vers un module actif : le chemin où aller, et le module
/// désactivé qu'on voulait ouvrir (la snackbar le nomme).
typedef ModuleRedirect = ({String location, AppModule module});

/// Où envoyer [location] quand elle est sous la racine d'un module du
/// [registry] qui n'est pas [active] : à la racine du premier module actif.
/// Null pour y rester : chemin d'aucun module ou d'un module actif, aucun
/// module actif, ou activation pas encore connue ([active] null, profil en
/// chargement) — attendre plutôt que rediriger trop tôt.
ModuleRedirect? moduleRedirect(
  List<AppModule> registry,
  List<AppModule>? active,
  String location,
) {
  if (active == null || active.isEmpty) return null;
  final activeIds = {for (final module in active) module.id};
  for (final module in registry) {
    if (activeIds.contains(module.id)) continue;
    final root = module.rootPath;
    if (location == root || location.startsWith('$root/')) {
      return (location: active.first.rootPath, module: module);
    }
  }
  return null;
}
