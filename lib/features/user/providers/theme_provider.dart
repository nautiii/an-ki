import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thème du dernier profil chargé sur ce téléphone
/// ([DeviceSettings.lastThemeMode]), lu par `main` avant la première image et
/// injecté ici ; null par défaut (premier lancement, tests).
final rememberedThemeModeProvider = Provider<ThemeMode?>((ref) => null);

/// Thème de l'app : la préférence du profil chargé. Sans profil (démarrage,
/// déconnexion), le dernier thème d'un profil dans cette exécution, sinon
/// celui retenu sur ce téléphone, sinon celui du système : le démarrage se
/// peint d'emblée dans le bon thème, sans passer par celui du système.
///
/// Vit dans la feature `user` car sa source de vérité est le profil ; `app/`
/// l'observe pour configurer [MaterialApp]. Le changer passe par
/// `userProfileEditorProvider`.
final themeProvider = NotifierProvider<AppThemeMode, ThemeMode>(
  AppThemeMode.new,
);

/// Voir [themeProvider].
class AppThemeMode extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final theme = ref.watch(
      userProfileProvider.select((profile) => profile.value?.theme),
    );
    if (theme != null) return _modeOf(theme);
    return stateOrNull ??
        ref.watch(rememberedThemeModeProvider) ??
        ThemeMode.system;
  }
}

/// Effet : retient sur ce téléphone le thème de chaque profil chargé, pour le
/// prochain démarrage. `app/` le garde actif.
final themeMemoryProvider = Provider<void>((ref) {
  // Déjà sur le téléphone : rien à réécrire à chaque lancement.
  var kept = ref.read(rememberedThemeModeProvider);
  ref.listen(
    userProfileProvider.select((profile) => profile.value?.theme),
    fireImmediately: true,
    (_, theme) {
      if (theme == null) return;
      final mode = _modeOf(theme);
      if (mode == kept) return;
      kept = mode;
      // Un échec du stockage ne coûte qu'un démarrage dans le thème système.
      ref.read(deviceSettingsProvider).keepThemeMode(mode).ignore();
    },
  );
});

ThemeMode _modeOf(ThemePreference theme) => switch (theme) {
  ThemePreference.light => ThemeMode.light,
  ThemePreference.dark => ThemeMode.dark,
  ThemePreference.system => ThemeMode.system,
};
