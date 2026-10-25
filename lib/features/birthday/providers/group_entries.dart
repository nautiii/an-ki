import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lignes de la page Groupes : les groupes de l'utilisateur, leur nature
/// (verrouillé, privé, partagé) et le nombre d'anniversaires de chacun.
final groupEntriesProvider = Provider<List<GroupEntry>>(
  (ref) => groupEntries(
    ref.watch(userCategoriesProvider),
    ownIds: [
      for (final group
          in ref.watch(ownCategoriesProvider).value ??
              const <BirthdayCategory>[])
        group.id,
    ],
    birthdays: ref.watch(birthdaysListProvider),
  ),
);
