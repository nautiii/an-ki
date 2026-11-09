import 'package:an_ki/app/modules/app_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// Racine de l'onglet du module de test.
const probeRoot = '/probe';

/// Module de test : un onglet « Sonde » (icône [Icons.science_outlined]) dont
/// l'écran dit « Écran sonde », éteint par défaut, et les [effects], la
/// section des Réglages et les [data] donnés. Un autre [id] lui donne un nom
/// et une racine à lui (`/<id>`).
AppModule probeModule({
  String id = 'probe',
  bool enabledByDefault = false,
  List<ProviderListenable<Object?>> effects = const [],
  Widget? settingsSection,
  ModuleData? data,
}) {
  final root = id == 'probe' ? probeRoot : '/$id';
  final name = id == 'probe' ? 'Sonde' : id;
  return AppModule(
    id: id,
    alwaysOn: false,
    enabledByDefault: enabledByDefault,
    icon: Icons.science_outlined,
    selectedIcon: Icons.science_rounded,
    name: (_) => name,
    description: (_) => 'Un module de test',
    rootPath: root,
    buildBranch: () => StatefulShellBranch(
      routes: [
        GoRoute(
          path: root,
          builder: (_, _) =>
              Scaffold(body: Text('Écran ${name.toLowerCase()}')),
        ),
      ],
    ),
    settingsSection: settingsSection,
    effects: effects,
    data: data,
  );
}
