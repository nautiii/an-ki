import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Création, modification et retrait des groupes (ViewModel de la ligne de
/// groupes de la feuille d'anniversaire et de la page Groupes) et état de la
/// dernière écriture : `AsyncLoading`, puis `AsyncData` ou `AsyncError`.
///
/// Écritures optimistes : Firestore les applique aussitôt au cache local,
/// hors ligne compris ; l'écran d'accueil écoute ce provider pour signaler
/// un échec.
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

  /// Renomme ou recolore le groupe privé [group]. Hors session, rien.
  void edit(BirthdayCategory group) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final categories = ref.read(categoryRepositoryProvider);
    final trimmed = BirthdayCategory(
      id: group.id,
      name: group.name.trim(),
      icon: group.icon,
      tone: group.tone,
    );
    unawaited(_write(() => categories.updateCategory(uid, trimmed)));
  }

  /// Retire [groupId] de l'utilisateur : un groupe privé ([kind] `own`) est
  /// supprimé, une catégorie partagée quitte son profil ; dans les deux cas,
  /// ses anniversaires le perdent. Un groupe verrouillé ne bouge pas.
  Future<void> remove(String groupId, GroupKind kind) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || kind == GroupKind.preset) return;
    // Tous les anniversaires, même ceux en cours de suppression : rattrapés,
    // ils ne doivent pas ramener le groupe.
    final carriers = [
      for (final birthday
          in ref.read(birthdaysProvider).value ?? const <Birthday>[])
        if (birthday.categories.contains(groupId)) birthday.id,
    ];
    final categories = ref.read(categoryRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    final birthdays = ref.read(birthdayRepositoryProvider);
    await _write(
      () => Future.wait([
        if (kind == GroupKind.own)
          categories.deleteCategory(uid, groupId)
        else
          users.removeCategory(uid, groupId),
        if (carriers.isNotEmpty) birthdays.removeCategory(carriers, groupId),
      ]),
    );
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
