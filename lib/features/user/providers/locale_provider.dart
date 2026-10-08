import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langue de l'app : celle du profil, sinon le français (langue de référence).
///
/// Vit dans la feature `user` car sa source de vérité est le profil ; `app/`
/// l'observe pour configurer [MaterialApp]. La changer passe par
/// `userProfileEditorProvider`.
final localeProvider = Provider<Locale>((ref) {
  final languageCode = ref.watch(
    userProfileProvider.select((profile) => profile.value?.locale),
  );
  return Locale(languageCode ?? 'fr');
});
