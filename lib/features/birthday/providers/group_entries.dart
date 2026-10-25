import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lignes de la page Groupes : les groupes de l'utilisateur, leur nature
/// (verrouillé, privé, partagé) et le nombre d'anniversaires de chacun. En
/// erreur si les groupes n'ont pu être lus, en chargement tant que le profil
/// et les groupes ne sont pas arrivés.
final groupEntriesProvider = Provider<AsyncValue<List<GroupEntry>>>((ref) {
  final shared = ref.watch(sharedCategoriesProvider);
  final own = ref.watch(ownCategoriesProvider);
  final profile = ref.watch(userProfileProvider);
  for (final source in [shared, own]) {
    if (source case AsyncValue(
      hasError: true,
      :final error?,
      :final stackTrace?,
    )) {
      return AsyncError(error, stackTrace);
    }
  }
  if (!shared.hasValue || !own.hasValue || !profile.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData(
    groupEntries(
      ref.watch(userCategoriesProvider),
      ownIds: [
        for (final group in own.value ?? const <BirthdayCategory>[]) group.id,
      ],
      birthdays: ref.watch(birthdaysListProvider),
    ),
  );
});
