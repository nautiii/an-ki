import 'package:an_ki/app/modules/app_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// Racine de l'onglet du module de test.
const probeRoot = '/probe';

/// Module de test : un onglet « Sonde » (icône [Icons.science_outlined]) dont
/// l'écran dit « Écran sonde », et les [effects] donnés.
AppModule probeModule({
  List<ProviderListenable<Object?>> effects = const [],
  Widget? settingsSection,
}) => AppModule(
  id: 'probe',
  alwaysOn: false,
  enabledByDefault: false,
  icon: Icons.science_outlined,
  selectedIcon: Icons.science_rounded,
  name: (_) => 'Sonde',
  description: (_) => 'Un module de test',
  rootPath: probeRoot,
  buildBranch: () => StatefulShellBranch(
    routes: [
      GoRoute(
        path: probeRoot,
        builder: (_, _) => const Scaffold(body: Text('Écran sonde')),
      ),
    ],
  ),
  settingsSection: settingsSection,
  effects: effects,
);
