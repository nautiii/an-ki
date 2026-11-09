import 'dart:async';

import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Effacement des données d'un module (ViewModel du dialogue de l'écran
/// Modules) et son issue : `AsyncLoading` pendant l'effacement, `AsyncError`
/// portant l'erreur de l'effaceur (hors ligne : il lit sur le serveur avant
/// d'écrire, et refuse sans rien effacer), sinon `AsyncData`.
///
/// Le même effaceur que la suppression du compte ([moduleErasersProvider]) ;
/// le module garde son état, actif ou non.
class ModuleDataEraser extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Efface toutes les données du module [moduleId] du compte connecté ;
  /// true une fois fait. Sans session, sans données à effacer pour ce module
  /// ou pendant un effacement, ne fait rien.
  Future<bool> erase(String moduleId) async {
    if (state.isLoading) return false;
    final uid = ref.read(currentUidProvider);
    final eraser = ref.read(moduleErasersProvider)[moduleId];
    if (uid == null || eraser == null) return false;
    // En vie jusqu'au bout, même si le dialogue disparaît.
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      await eraser(uid);
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return false;
    } finally {
      keepAlive.close();
    }
  }
}

final moduleDataEraserProvider =
    AsyncNotifierProvider.autoDispose<ModuleDataEraser, void>(
      ModuleDataEraser.new,
    );
