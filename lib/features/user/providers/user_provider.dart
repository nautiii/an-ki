import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserState {
  final UserModel? user;
  final bool isLoading;

  UserState({this.user, this.isLoading = false});

  UserState copyWith({UserModel? user, bool? isLoading}) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => UserState();

  UserRepository get _repository => ref.watch(userRepositoryProvider);

  Future<void> loadUser(String uid) async {
    try {
      state = state.copyWith(isLoading: true);

      final user = await _repository.fetchUser(uid);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'utilisateur: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> createUser({
    required String uid,
    required String name,
    required String surname,
  }) async {
    final newUser = UserModel(id: uid, name: name, surname: surname);
    await _repository.createUser(newUser);
    state = state.copyWith(user: newUser);
  }

  Future<void> updatePseudo(String pseudo) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(pseudo: pseudo);
    await _repository.updateUser(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  void clear() {
    state = UserState();
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
