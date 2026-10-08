import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profil Firestore de l'utilisateur courant, en temps réel ; null hors
/// session ou tant que le document n'existe pas (premier lancement d'un
/// compte : `app/bootstrap` le crée).
///
/// Dérivé de [currentUidProvider] : rien à charger ni à vider à la main.
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});
