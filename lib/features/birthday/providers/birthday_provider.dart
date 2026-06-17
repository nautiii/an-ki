import 'dart:async';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BirthdayState {
  final List<BirthdayModel> birthdays;
  final bool isLoading;
  final bool isCreating;

  BirthdayState({
    this.birthdays = const [],
    this.isLoading = true,
    this.isCreating = false,
  });

  BirthdayState copyWith({
    List<BirthdayModel>? birthdays,
    bool? isLoading,
    bool? isCreating,
  }) {
    return BirthdayState(
      birthdays: birthdays ?? this.birthdays,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}

class BirthdayNotifier extends Notifier<BirthdayState> {
  @override
  BirthdayState build() {
    ref.onDispose(() => _subscription?.cancel());
    return BirthdayState();
  }

  BirthdayRepository get _repository => ref.watch(birthdayRepositoryProvider);
  StreamSubscription<List<BirthdayModel>>? _subscription;

  void startListening(String uid) {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true);

    _subscription = _repository
        .watchBirthdays(uid)
        .listen(
          (List<BirthdayModel> data) {
            if (ref.mounted) {
              state = state.copyWith(birthdays: data, isLoading: false);
              NotificationService.instance.scheduleAll(data);
            }
          },
          onError: (e) {
            if (ref.mounted) {
              state = state.copyWith(isLoading: false);
            }
          },
        );
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    state = BirthdayState();
  }

  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {
    if (state.isCreating) {
      return;
    }

    state = state.copyWith(isCreating: true);

    try {
      await _repository.createBirthday(uid, input);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isCreating: false);
      }
    }
  }

  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async {
    if (state.isCreating) {
      return;
    }

    state = state.copyWith(isCreating: true);

    try {
      await _repository.updateBirthday(uid, birthdayId, input);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isCreating: false);
      }
    }
  }

  Future<void> deleteBirthday(String uid, String birthdayId) async {
    await _repository.deleteBirthday(uid, birthdayId);
  }

  Future<int> importFromContacts(String uid) async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted) {
      throw Exception('Permission refusée');
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.event, ContactProperty.name},
    );
    int importedCount = 0;

    for (final contact in contacts) {
      final birthdayEvent = contact.events.cast<Event?>().firstWhere(
        (e) => e?.label.label == EventLabel.birthday,
        orElse: () => null,
      );

      if (birthdayEvent != null) {
        final birthDate = DateTime(
          birthdayEvent.year ?? 2000,
          birthdayEvent.month,
          birthdayEvent.day,
        );

        final input = CreateBirthdayInput(
          uid: uid,
          name: contact.name?.first ?? "",
          surname: contact.name?.last ?? "",
          date: birthDate,
          categories: [],
        );

        await _repository.createBirthday(uid, input);
        importedCount++;
      }
    }
    return importedCount;
  }
}

final birthdayProvider = NotifierProvider<BirthdayNotifier, BirthdayState>(
  BirthdayNotifier.new,
);

/// Provider pour récupérer uniquement la liste des anniversaires
final birthdaysListProvider = Provider<List<BirthdayModel>>((ref) {
  return ref.watch(birthdayProvider.select((s) => s.birthdays));
});

/// Provider pour calculer le prochain anniversaire (ou les prochains si même jour)
final nextBirthdaysProvider = Provider<List<BirthdayModel>>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.nextBirthdays;
});

/// Notifier pour gérer la chaîne de recherche
class BirthdaySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final birthdaySearchProvider = NotifierProvider<BirthdaySearchNotifier, String>(
  BirthdaySearchNotifier.new,
);

/// Notifier pour gérer les catégories filtrées (par ID)
class BirthdayCategoryFilterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void update(List<String> value) => state = value;
}

final birthdayCategoryFilterProvider =
    NotifierProvider<BirthdayCategoryFilterNotifier, List<String>>(
      BirthdayCategoryFilterNotifier.new,
    );

/// Provider pour filtrer les anniversaires (recherche + exclusion des prochains + catégories)
final filteredBirthdaysProvider = Provider<List<BirthdayModel>>((ref) {
  final allBirthdays = ref.watch(birthdaysListProvider);
  final nextBirthdays = ref.watch(nextBirthdaysProvider);
  final nextIds = nextBirthdays.map((b) => b.id).toSet();
  final searchQuery = ref.watch(birthdaySearchProvider).toLowerCase();
  final categoryFilters = ref.watch(birthdayCategoryFilterProvider);

  // 1. Filtrer et Trier
  final filtered =
      allBirthdays.where((birthday) {
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
      }).toList();

  // 2. Trier par proximité (jours restants)
  filtered.sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));

  return filtered;
});

/// Provider pour filtrer les anniversaires par catégories et recherche (SANS exclusion du prochain)
/// Utile pour la vue calendrier
final categoryFilteredBirthdaysProvider = Provider<List<BirthdayModel>>((ref) {
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
