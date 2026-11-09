import 'dart:async';

import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifications du profil (pseudo, thème, langue, modules) et état de la
/// dernière :
/// `AsyncLoading` pendant l'écriture, `AsyncError` si elle échoue.
///
/// Écritures optimistes : Firestore met le profil à jour dans son cache tout
/// de suite, donc le thème et la langue (dérivés du profil) changent sans
/// attendre le serveur. L'écran des réglages écoute ce provider pour signaler
/// un échec.
class UserProfileEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updatePseudo(String pseudo) => _update(pseudo: pseudo);

  Future<void> setTheme(ThemePreference theme) => _update(theme: theme);

  Future<void> setLocale(String languageCode) => _update(locale: languageCode);

  /// Choix explicite pour le module [moduleId] : `app/` en déduit les modules
  /// actifs, la feature `user` ne stocke que l'id.
  Future<void> setModuleEnabled(String moduleId, {required bool enabled}) =>
      _write(
        (repository, uid) =>
            repository.setModuleEnabled(uid, moduleId, enabled: enabled),
      );

  /// Écrit les seuls champs donnés.
  Future<void> _update({
    String? pseudo,
    ThemePreference? theme,
    String? locale,
  }) => _write(
    (repository, uid) => repository.updatePreferences(
      uid,
      pseudo: pseudo,
      theme: theme,
      locale: locale,
    ),
  );

  /// Lance l'écriture [write] sur le profil chargé et publie son issue ; sans
  /// profil chargé, ne fait rien.
  Future<void> _write(
    Future<void> Function(UserRepository repository, String uid) write,
  ) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => write(repository, user.id));
    if (ref.mounted) state = result;
  }
}

final userProfileEditorProvider =
    AsyncNotifierProvider.autoDispose<UserProfileEditor, void>(
      UserProfileEditor.new,
    );
