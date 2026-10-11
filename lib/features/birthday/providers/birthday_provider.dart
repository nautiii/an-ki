import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anniversaires de l'utilisateur courant, en temps réel ; liste vide hors
/// session.
///
/// Dérivé de [currentUidProvider] : connexion, changement de compte et
/// déconnexion relancent ou coupent l'abonnement Firestore sans code
/// d'initialisation ni remise à zéro manuelle.
final birthdaysProvider = StreamProvider<List<Birthday>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(birthdayRepositoryProvider).watchBirthdays(uid);
});

/// Vrai tant que la première liste n'est pas arrivée (ni donnée ni erreur).
final birthdaysLoadingProvider = Provider<bool>((ref) {
  final birthdays = ref.watch(birthdaysProvider);
  return birthdays.isLoading && !birthdays.hasValue && !birthdays.hasError;
});

/// Liste courante des anniversaires : vide pendant le premier chargement ou
/// en cas d'erreur, la précédente pendant un rechargement.
final birthdaysListProvider = Provider<List<Birthday>>(
  (ref) => ref.watch(birthdaysProvider).value ?? const [],
);

/// Le ou les prochains anniversaires (plusieurs s'ils tombent le même jour),
/// recalculés quand le jour change.
final nextBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.nextBirthdays(ref.watch(todayProvider));
});

/// Texte de recherche, remis à zéro quand l'utilisateur change.
class BirthdaySearchNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUidProvider);
    return '';
  }

  void update(String value) => state = value;
}

final birthdaySearchProvider = NotifierProvider<BirthdaySearchNotifier, String>(
  BirthdaySearchNotifier.new,
);

/// Catégories filtrées (par id), remises à zéro quand l'utilisateur change.
class BirthdayCategoryFilterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(currentUidProvider);
    return const [];
  }

  void update(List<String> value) => state = value;
}

final birthdayCategoryFilterProvider =
    NotifierProvider<BirthdayCategoryFilterNotifier, List<String>>(
      BirthdayCategoryFilterNotifier.new,
    );

/// Provider pour filtrer les anniversaires (recherche + exclusion des prochains + catégories)
final filteredBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final allBirthdays = ref.watch(birthdaysListProvider);
  final nextBirthdays = ref.watch(nextBirthdaysProvider);
  final nextIds = nextBirthdays.map((b) => b.id).toSet();
  final searchQuery = ref.watch(birthdaySearchProvider).toLowerCase();
  final categoryFilters = ref.watch(birthdayCategoryFilterProvider);
  final today = ref.watch(todayProvider);

  // 1. Filtrer
  final filtered = allBirthdays.where((birthday) {
    // Exclure le ou les prochains anniversaires (déjà affichés en haut)
    if (nextIds.contains(birthday.id)) return false;

    // Filtrer par catégories (doit posséder TOUTES les catégories sélectionnées)
    if (categoryFilters.isNotEmpty) {
      final hasAllCategories = categoryFilters.every(
        (catId) => birthday.categories.contains(catId),
      );
      if (!hasAllCategories) return false;
    }

    // Filtrer par recherche
    if (searchQuery.isEmpty) return true;
    return birthday.name.toLowerCase().contains(searchQuery) ||
        birthday.surname.toLowerCase().contains(searchQuery);
  });

  // 2. Trier par proximité (jours restants)
  return filtered.sortedByNext(today);
});

/// Provider pour filtrer les anniversaires par catégories et recherche (SANS exclusion du prochain)
/// Utile pour la vue calendrier
final categoryFilteredBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final allBirthdays = ref.watch(birthdaysListProvider);
  final searchQuery = ref.watch(birthdaySearchProvider).toLowerCase();
  final categoryFilters = ref.watch(birthdayCategoryFilterProvider);

  return allBirthdays.where((birthday) {
    // Filtrer par catégories
    if (categoryFilters.isNotEmpty) {
      final hasAllCategories = categoryFilters.every(
        (catId) => birthday.categories.contains(catId),
      );
      if (!hasAllCategories) return false;
    }

    // Filtrer par recherche
    if (searchQuery.isEmpty) return true;
    return birthday.name.toLowerCase().contains(searchQuery) ||
        birthday.surname.toLowerCase().contains(searchQuery);
  }).toList();
});
