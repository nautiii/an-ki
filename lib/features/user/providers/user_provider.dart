import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
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
    // On évite de dépendre de themeProvider pour casser la dépendance circulaire
    final isPlatformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;

    final newUser = UserModel(
      id: uid,
      name: name,
      surname: surname,
      isDark: isPlatformDark,
      locale: 'fr',
    );
    // createUser is create-if-absent: if the document already exists (e.g. the
    // initial load failed transiently), the existing profile is returned
    // untouched instead of being overwritten.
    final effectiveUser = await _repository.createUser(newUser);
    state = state.copyWith(user: effectiveUser);
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
