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

/// Toutes les catégories que les anniversaires peuvent porter, partagées et
/// privées ; vide tant qu'elles chargent.
final categoriesProvider = Provider<List<BirthdayCategory>>(
  (ref) => [
    ...?ref.watch(sharedCategoriesProvider).value,
    ...?ref.watch(ownCategoriesProvider).value,
  ],
);

/// Groupes de l'utilisateur, dans l'ordre de leur ligne de puces : ceux
/// proposés à tous, puis les siens (`userGroups`).
final userCategoriesProvider = Provider<List<BirthdayCategory>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return const [];
  return userGroups(
    shared: ref.watch(sharedCategoriesProvider).value ?? const [],
    pickedIds: user.categories,
    own: ref.watch(ownCategoriesProvider).value ?? const [],
  );
});
