import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catégories du profil (ViewModel des actions de la feuille des catégories)
/// et état de la dernière écriture : `AsyncLoading`, puis `AsyncData` ou
/// `AsyncError`.
///
/// Écritures optimistes : la feuille se ferme sans attendre (Firestore
/// applique tout au cache local, hors ligne compris) ; l'écran d'accueil
/// écoute ce provider pour signaler un échec.
class CategoryEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Ajoute au profil des catégories existantes, sans doublon.
  Future<void> addToProfile(List<String> categoryIds) => _write(
    (uid) => ref.read(userRepositoryProvider).addCategories(uid, categoryIds),
  );

  /// Crée une catégorie et l'ajoute au profil. Son id est généré localement :
  /// le profil la référence sans attendre le serveur.
  Future<void> create(String name, int icon) => _write((uid) {
    final categories = ref.read(categoryRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    final category = BirthdayCategory(
      id: categories.newCategoryId(),
      name: name,
      icon: icon,
    );
    return Future.wait([
      categories.createCategory(category),
      users.addCategories(uid, [category.id]),
    ]);
  });

  /// Exécute une écriture pour l'utilisateur courant et publie son issue.
  /// Hors session, ne fait rien.
  Future<void> _write(Future<void> Function(String uid) write) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => write(uid));
    // Le provider a pu être libéré pendant l'attente (écran fermé).
    if (ref.mounted) state = result;
  }
}

final categoryEditorProvider =
    AsyncNotifierProvider.autoDispose<CategoryEditor, void>(CategoryEditor.new);
