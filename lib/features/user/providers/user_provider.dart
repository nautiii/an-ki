import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/birthday_repository.dart';
import '../../birthday/providers/birthday_provider.dart';

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
    final newUser = UserModel(
      id: uid,
      name: name,
      surname: surname,
      isDark: ref.read(themeProvider.notifier).isDark,
      locale: 'fr',
    );
    await _repository.createUser(newUser);
    state = state.copyWith(user: newUser);
  }

  Future<void> updatePseudo(String pseudo) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(pseudo: pseudo);
    await _repository.updateUser(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  Future<void> updateTheme(bool isDark) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(isDark: isDark);
    await _repository.updateUser(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  Future<void> updateLocale(String locale) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(locale: locale);
    await _repository.updateUser(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  Future<void> deleteAccount(String uid) async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Supprimer tous les anniversaires
      await ref.read(birthdayRepositoryProvider).deleteAllUserBirthdays(uid);

      // 2. Supprimer l'utilisateur de Firestore
      await _repository.deleteUser(uid);

      // 3. Nettoyer les états locaux
      clear();
      ref.read(birthdayProvider.notifier).clear();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void clear() {
    state = UserState();
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
