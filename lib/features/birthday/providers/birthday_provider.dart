import 'dart:async';

import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
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

class BirthdayProvider extends StateNotifier<BirthdayState> {
  final BirthdayRepository _repository;
  StreamSubscription<List<BirthdayModel>>? _subscription;

  BirthdayProvider(this._repository) : super(BirthdayState());

  void startListening(String uid) {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true);

    _subscription = _repository.watchBirthdays(uid).listen(
      (List<BirthdayModel> data) {
        state = state.copyWith(birthdays: data, isLoading: false);
        NotificationService.instance.scheduleAll(data);
      },
      onError: (e) {
        state = state.copyWith(isLoading: false);
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
      state = state.copyWith(isCreating: false);
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
      state = state.copyWith(isCreating: false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final birthdayProvider =
    StateNotifierProvider<BirthdayProvider, BirthdayState>((ref) {
      final repository = ref.watch(birthdayRepositoryProvider);
      return BirthdayProvider(repository);
    });
