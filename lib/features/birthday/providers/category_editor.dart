import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Création des groupes (ViewModel de la ligne de groupes de la feuille
/// d'anniversaire) et état de la dernière écriture : `AsyncLoading`, puis
/// `AsyncData` ou `AsyncError`.
///
/// Écriture optimiste : le groupe apparaît aussitôt (Firestore l'applique au
/// cache local, hors ligne compris) ; l'écran d'accueil écoute ce provider
/// pour signaler un échec.
class CategoryEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Crée un groupe privé et rend son id tout de suite : la feuille le coche
  /// sans attendre le serveur. Hors session, rien n'est créé (null).
  String? create(String name, {required int icon, required int tone}) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return null;
    final categories = ref.read(categoryRepositoryProvider);
    final category = BirthdayCategory(
      id: categories.newCategoryId(),
      name: name.trim(),
      icon: icon,
      tone: tone,
    );
    unawaited(_write(() => categories.createCategory(uid, category)));
    return category.id;
  }

  /// Exécute une écriture et publie son issue.
  Future<void> _write(Future<void> Function() write) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(write);
    // Le provider a pu être libéré pendant l'attente (feuille fermée).
    if (ref.mounted) state = result;
  }
}

final categoryEditorProvider =
    AsyncNotifierProvider.autoDispose<CategoryEditor, void>(CategoryEditor.new);
