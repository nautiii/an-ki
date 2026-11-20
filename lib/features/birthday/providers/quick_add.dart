import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'ajout s'ouvre en une ligne plutôt qu'en formulaire : le dernier mode
/// choisi par l'utilisateur connecté ([UserProfile.quickAddPreferred]). Le
/// formulaire tant que le profil n'est pas chargé, et par défaut.
final quickAddPreferredProvider = Provider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  final user = ref.watch(userProfileProvider).value;
  return uid != null && user?.id == uid && user!.quickAddPreferred;
});
