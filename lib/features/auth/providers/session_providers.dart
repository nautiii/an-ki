import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifiant de l'utilisateur courant, ou null hors session.
///
/// Toutes les données utilisateur en dérivent : quand il change (connexion,
/// changement de compte, déconnexion), les providers qui le `watch` se
/// reconstruisent seuls — aucun `startListening` ni `clear` à appeler.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((s) => s.uid)),
);
