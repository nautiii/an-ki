import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langue choisie dans le profil ; null sans choix (ni profil chargé) : l'app
/// suit alors la langue du téléphone.
///
/// Vit dans la feature `user` car sa source de vérité est le profil ; `app/`
/// la combine avec les langues du téléphone et les traductions disponibles
/// (`appLocaleProvider`). La changer passe par `userProfileEditorProvider`.
final localeProvider = Provider<Locale?>((ref) {
  final languageCode = ref.watch(
    userProfileProvider.select((profile) => profile.value?.locale),
  );
  return languageCode == null ? null : Locale(languageCode);
});
