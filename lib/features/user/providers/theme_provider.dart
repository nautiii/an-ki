import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thème de l'app : la préférence enregistrée dans le profil ; celui du
/// système par défaut et tant que le profil n'est pas chargé.
///
/// Vit dans la feature `user` car sa source de vérité est le profil ; `app/`
/// l'observe pour configurer [MaterialApp]. Le changer passe par
/// `userProfileEditorProvider`.
final themeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(
    userProfileProvider.select((profile) => profile.value?.theme),
  );
  return switch (theme) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system || null => ThemeMode.system,
  };
});
