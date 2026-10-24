import 'dart:async';

import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifications du profil (pseudo, thème, langue) et état de la dernière :
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

  /// Écrit les seuls champs donnés ; sans profil chargé, ne fait rien.
  Future<void> _update({
    String? pseudo,
    ThemePreference? theme,
    String? locale,
  }) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => repository.updatePreferences(
        user.id,
        pseudo: pseudo,
        theme: theme,
        locale: locale,
      ),
    );
    if (ref.mounted) state = result;
  }
}

final userProfileEditorProvider =
    AsyncNotifierProvider.autoDispose<UserProfileEditor, void>(
      UserProfileEditor.new,
    );
