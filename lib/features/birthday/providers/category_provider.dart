import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catégories partagées : prédéfinies, et groupes créés avant qu'ils soient
/// privés.
final sharedCategoriesProvider = StreamProvider<List<BirthdayCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

/// Groupes privés de l'utilisateur connecté ; aucun hors session.
final ownCategoriesProvider = StreamProvider<List<BirthdayCategory>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(categoryRepositoryProvider).watchOwnCategories(uid);
});

/// Groupes supprimés ou retirés mais encore rattrapables : masqués partout
/// (puces, filtres, page Groupes) pendant le délai « Annuler », puis jusqu'à
/// la fin de l'écriture. Vide à chaque changement d'utilisateur.
class PendingGroupRemovals extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const {};
  }

  void hide(String groupId) => state = {...state, groupId};

  void restore(String groupId) => state = {
    for (final id in state)
      if (id != groupId) id,
  };
}

final pendingGroupRemovalsProvider =
    NotifierProvider<PendingGroupRemovals, Set<String>>(
      PendingGroupRemovals.new,
    );

/// [categories] sans les groupes en cours de retrait.
List<BirthdayCategory> _visible(Ref ref, List<BirthdayCategory> categories) {
  final pending = ref.watch(pendingGroupRemovalsProvider);
  if (pending.isEmpty) return categories;
  return [
    for (final category in categories)
      if (!pending.contains(category.id)) category,
  ];
}

/// Toutes les catégories que les anniversaires peuvent porter, partagées et
/// privées, sans celles en cours de retrait ; vide tant qu'elles chargent.
final categoriesProvider = Provider<List<BirthdayCategory>>(
  (ref) => _visible(ref, [
    ...?ref.watch(sharedCategoriesProvider).value,
    ...?ref.watch(ownCategoriesProvider).value,
  ]),
);

/// Groupes de l'utilisateur, dans l'ordre de leur ligne de puces : ceux
/// proposés à tous, puis les siens (`userGroups`), sans ceux en cours de
/// retrait.
final userCategoriesProvider = Provider<List<BirthdayCategory>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return const [];
  return _visible(
    ref,
    userGroups(
      shared: ref.watch(sharedCategoriesProvider).value ?? const [],
      pickedIds: user.categories,
      own: ref.watch(ownCategoriesProvider).value ?? const [],
    ),
  );
});
