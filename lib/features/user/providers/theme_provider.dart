import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thème de l'app : la préférence enregistrée dans le profil, sinon celui du
/// système.
///
/// Vit dans la feature `user` car sa source de vérité est le profil ; `app/`
/// l'observe pour configurer [MaterialApp]. Le changer passe par
/// `userProfileEditorProvider`.
final themeProvider = Provider<ThemeMode>((ref) {
  final isDark = ref.watch(
    userProfileProvider.select((profile) => profile.value?.isDark),
  );
  return switch (isDark) {
    true => ThemeMode.dark,
    false => ThemeMode.light,
    null => ThemeMode.system,
  };
});
