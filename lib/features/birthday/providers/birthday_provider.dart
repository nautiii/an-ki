import 'dart:async';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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

  Future<void> deleteBirthday(String birthdayId) async {
    await _repository.deleteBirthday(birthdayId);
  }
}

final birthdayProvider = NotifierProvider<BirthdayNotifier, BirthdayState>(
  BirthdayNotifier.new,
);

/// Provider pour récupérer uniquement la liste des anniversaires
final birthdaysListProvider = Provider<List<BirthdayModel>>((ref) {
  return ref.watch(birthdayProvider.select((s) => s.birthdays));
});

/// Provider pour calculer le prochain anniversaire
final nextBirthdayProvider = Provider<BirthdayModel?>((ref) {
  final birthdays = ref.watch(birthdaysListProvider);
  return birthdays.nextBirthday;
});

/// Provider pour gérer la chaîne de recherche
final birthdaySearchProvider = StateProvider<String>((ref) => '');

/// Provider pour filtrer les anniversaires (recherche + exclusion du prochain)
final filteredBirthdaysProvider = Provider<List<BirthdayModel>>((ref) {
  final allBirthdays = ref.watch(birthdaysListProvider);
  final nextBirthday = ref.watch(nextBirthdayProvider);
  final searchQuery = ref.watch(birthdaySearchProvider).toLowerCase();

  return allBirthdays.where((birthday) {
    // Exclure le prochain anniversaire (déjà affiché en haut)
    if (birthday.id == nextBirthday?.id) return false;

    // Filtrer par recherche
    if (searchQuery.isEmpty) return true;
    return birthday.name.toLowerCase().contains(searchQuery) ||
        birthday.surname.toLowerCase().contains(searchQuery);
  }).toList();
});
