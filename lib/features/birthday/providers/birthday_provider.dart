import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
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

/// Anniversaires supprimés mais encore rattrapables : masqués partout pendant
/// le délai « Annuler », puis jusqu'à la fin de l'écriture. Vide à chaque
/// changement d'utilisateur.
class PendingDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const {};
  }

  void hide(String birthdayId) => state = {...state, birthdayId};

  void restore(String birthdayId) => state = {
    for (final id in state)
      if (id != birthdayId) id,
  };
}

final pendingDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

/// Liste courante des anniversaires, sans ceux en cours de suppression :
/// vide pendant le premier chargement ou en cas d'erreur, la précédente
/// pendant un rechargement.
final birthdaysListProvider = Provider<List<Birthday>>((ref) {
  final birthdays = ref.watch(birthdaysProvider).value ?? const [];
  final pending = ref.watch(pendingDeletionsProvider);
  if (pending.isEmpty) return birthdays;
  return [
    for (final birthday in birthdays)
      if (!pending.contains(birthday.id)) birthday,
  ];
});

/// Le ou les prochains anniversaires (plusieurs s'ils tombent le même jour),
/// recalculés quand le jour change.
final nextBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.nextBirthdays(ref.watch(todayProvider));
});

/// Personnes dont la pluie de pétales (S4) est déjà tombée aujourd'hui : une
/// fois par personne et par jour, tant que l'app tourne. Vide chaque jour et
/// à chaque changement d'utilisateur.
class CelebratedToday extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(todayProvider);
    ref.watch(currentUidProvider);
    return const {};
  }

  void add(String birthdayId) => state = {...state, birthdayId};
}

final celebratedTodayProvider = NotifierProvider<CelebratedToday, Set<String>>(
  CelebratedToday.new,
);

/// L'agenda de l'accueil : les anniversaires que le héros n'affiche pas,
/// « dans les 7 jours » puis par mois.
final agendaProvider = Provider<List<AgendaSection>>((ref) {
  final nextIds = {for (final b in ref.watch(nextBirthdaysProvider)) b.id};
  return ref
      .watch(birthdaysListProvider)
      .where((birthday) => !nextIds.contains(birthday.id))
      .agenda(ref.watch(todayProvider));
});

/// Texte de l'écran de recherche ; repart de zéro à chaque ouverture de
/// l'écran (autoDispose) et quand l'utilisateur change.
class BirthdaySearchNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUidProvider);
    return '';
  }

  void update(String value) => state = value;
}

final birthdaySearchProvider =
    NotifierProvider.autoDispose<BirthdaySearchNotifier, String>(
      BirthdaySearchNotifier.new,
    );

/// Catégories filtrées (par id) dans l'écran de recherche ; même cycle de vie
/// que le texte.
class BirthdayCategoryFilterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(currentUidProvider);
    return const [];
  }

  /// Ajoute la catégorie au filtre, ou l'en retire si elle y est déjà.
  void toggle(String categoryId) => state = state.contains(categoryId)
      ? [
          for (final id in state)
            if (id != categoryId) id,
        ]
      : [...state, categoryId];

  void clear() => state = const [];
}

final birthdayCategoryFilterProvider =
    NotifierProvider.autoDispose<BirthdayCategoryFilterNotifier, List<String>>(
      BirthdayCategoryFilterNotifier.new,
    );

/// Groupes proposés comme filtres de la recherche (`groupFilters`) : ceux que
/// portent les anniversaires, à partir de deux, et ceux déjà choisis.
final groupFiltersProvider = Provider.autoDispose<List<BirthdayCategory>>(
  (ref) => groupFilters(
    ref.watch(userCategoriesProvider),
    ref.watch(birthdaysListProvider),
    selected: ref.watch(birthdayCategoryFilterProvider),
  ),
);

/// Résultats de l'écran de recherche : texte et catégories appliqués à tout le
/// carnet (héros compris), du plus proche au plus lointain.
final birthdaySearchResultsProvider = Provider.autoDispose<List<Birthday>>((
  ref,
) {
  return ref
      .watch(birthdaysListProvider)
      .matching(
        ref.watch(birthdaySearchProvider),
        categoryIds: ref.watch(birthdayCategoryFilterProvider),
      )
      .sortedByNext(ref.watch(todayProvider));
});
