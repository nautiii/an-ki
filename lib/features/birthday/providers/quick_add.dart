import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'ajout en une ligne remplace le formulaire : l'utilisateur connecté a
/// déjà ajouté quelqu'un avec ce dernier, et sait donc ce qu'AnKi attend
/// (un nom, une date). Faux tant que le profil n'est pas chargé.
final quickAddLearnedProvider = Provider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  final user = ref.watch(userProfileProvider).value;
  return uid != null && user?.id == uid && user!.quickAddLearned;
});

/// Note sur le profil le premier ajout fait à la main
/// ([birthdayAdditionsProvider], hors import) : dès le suivant, « + » ouvre
/// l'ajout en une ligne. Activé par `app/` (effet du module Anniversaires) :
/// Riverpod met en pause un provider que personne n'écoute.
final quickAddLearningProvider = Provider<void>((ref) {
  ref.listen(birthdayAdditionsProvider, (_, added) {
    if (added == null || added.imported) return;
    if (ref.read(quickAddLearnedProvider)) return;
    unawaited(ref.read(userProfileEditorProvider.notifier).learnQuickAdd());
  });
});
