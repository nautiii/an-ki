import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/providers/pending_ids.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
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

/// Anniversaires supprimés mais encore rattrapables : masqués partout
/// ([PendingIds]).
final pendingDeletionsProvider = NotifierProvider<PendingIds, Set<String>>(
  () => PendingIds(currentUidProvider),
);

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

/// L'anniversaire [birthdayId], pour sa page : chargement et erreur de la
/// liste tels quels, puis la personne, ou null si elle n'y est pas
/// (supprimée, en cours de suppression, ou d'un autre compte).
final birthdayByIdProvider = Provider.autoDispose
    .family<AsyncValue<Birthday?>, String>((ref, birthdayId) {
      final pending = ref.watch(pendingDeletionsProvider);
      return ref
          .watch(birthdaysProvider)
          .whenData(
            (birthdays) => pending.contains(birthdayId)
                ? null
                : birthdays.where((b) => b.id == birthdayId).firstOrNull,
          );
    });

/// Le ou les prochains anniversaires (plusieurs s'ils tombent le même jour),
/// recalculés quand le jour change.
final nextBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.nextBirthdays(ref.watch(todayProvider));
});

/// Anniversaires d'hier encore à souhaiter, en retard : le lendemain
/// seulement, recalculés quand le jour change.
final belatedBirthdaysProvider = Provider<List<Birthday>>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.belated(ref.watch(todayProvider));
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

/// Un écran de recherche : chacun a son propre état, même empilé sur un autre
/// (recherche › personne › groupe › recherche). [token] est créé une fois
/// par écran ; [initialCategoryId] est le groupe sur lequel il s'ouvre.
typedef SearchScope = ({Object token, String? initialCategoryId});

/// Texte d'un écran de recherche ; repart de zéro à chaque ouverture de
/// l'écran (autoDispose) et quand l'utilisateur change. [scope] ne sert qu'à
/// séparer les écrans : le texte part toujours vide.
class BirthdaySearchNotifier extends Notifier<String> {
  BirthdaySearchNotifier(this.scope);

  final SearchScope scope;

  @override
  String build() {
    ref.watch(currentUidProvider);
    return '';
  }

  void update(String value) => state = value;
}

final birthdaySearchProvider = NotifierProvider.autoDispose
    .family<BirthdaySearchNotifier, String, SearchScope>(
      BirthdaySearchNotifier.new,
    );

/// Catégories filtrées (par id) dans l'écran de recherche ; même cycle de vie
/// que le texte ; part du groupe d'ouverture, s'il y en a un.
class BirthdayCategoryFilterNotifier extends Notifier<List<String>> {
  BirthdayCategoryFilterNotifier(this.scope);

  final SearchScope scope;

  @override
  List<String> build() {
    ref.watch(currentUidProvider);
    final initial = scope.initialCategoryId;
    return initial == null ? const [] : [initial];
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

final birthdayCategoryFilterProvider = NotifierProvider.autoDispose
    .family<BirthdayCategoryFilterNotifier, List<String>, SearchScope>(
      BirthdayCategoryFilterNotifier.new,
    );

/// Groupes proposés comme filtres de la recherche (`groupFilters`) : ceux que
/// portent les anniversaires, à partir de deux, et ceux déjà choisis.
final groupFiltersProvider = Provider.autoDispose
    .family<List<BirthdayCategory>, SearchScope>(
      (ref, scope) => groupFilters(
        ref.watch(userCategoriesProvider),
        ref.watch(birthdaysListProvider),
        selected: ref.watch(birthdayCategoryFilterProvider(scope)),
      ),
    );

/// Résultats de l'écran de recherche : texte et catégories appliqués à tout le
/// carnet (héros compris), du plus proche au plus lointain.
final birthdaySearchResultsProvider = Provider.autoDispose
    .family<List<Birthday>, SearchScope>(
      (ref, scope) => ref
          .watch(birthdaysListProvider)
          .matching(
            ref.watch(birthdaySearchProvider(scope)),
            categoryIds: ref.watch(birthdayCategoryFilterProvider(scope)),
          )
          .sortedByNext(ref.watch(todayProvider)),
    );
