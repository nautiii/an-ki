import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Utilisateur Firebase de la session, ou null hors session, en temps réel :
/// connexion, déconnexion et changements du compte (liaison d'un compte
/// anonyme à Google, nom affiché).
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

/// Verrou biométrique : lu au démarrage depuis l'appareil (verrouillé si la
/// connexion par empreinte est configurée), puis modifié par les actions
/// d'authentification (`AuthController`).
class BiometricLockNotifier extends AsyncNotifier<BiometricLock> {
  @override
  Future<BiometricLock> build() async {
    final biometrics = ref.read(biometricServiceProvider);
    final canUse = await biometrics.canUseFingerprint();
    final hasToken = await biometrics.getStoredToken() != null;
    return BiometricLock(enabled: canUse && hasToken);
  }

  /// Ouvre l'app : connexion explicite, ou empreinte.
  void unlock() => _update((lock) => lock.copyWith(unlocked: true));

  /// Referme l'app sans quitter la session Firebase.
  void lock() => _update((lock) => lock.copyWith(unlocked: false));

  /// Connexion par empreinte activée : l'app reste ouverte.
  void enable() =>
      _update((lock) => lock.copyWith(enabled: true, unlocked: true));

  /// Connexion par empreinte retirée, ou déconnexion complète : la session
  /// Firebase redevient seule juge.
  void disable() => state = const AsyncData(BiometricLock.disabled);

  void _update(BiometricLock Function(BiometricLock lock) change) =>
      state = AsyncData(change(state.value ?? BiometricLock.disabled));
}

final biometricLockProvider =
    AsyncNotifierProvider<BiometricLockNotifier, BiometricLock>(
      BiometricLockNotifier.new,
    );

/// Identifiant de l'utilisateur de la session Firebase, ou null hors session.
/// Verrouillée, l'app le garde : données et rappels suivent derrière le verrou.
///
/// Toutes les données utilisateur en dérivent : quand il change (connexion,
/// changement de compte, déconnexion), les providers qui le `watch` se
/// reconstruisent seuls — aucun `startListening` ni `clear` à appeler.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider.select((user) => user.value?.uid)),
);

/// Session d'invité (compte anonyme, ouvert par « Commencer ») : AnKi le salue
/// sans nom. Faux hors session.
final isGuestProvider = Provider<bool>(
  (ref) => ref.watch(
    authUserProvider.select((user) => user.value?.isAnonymous ?? false),
  ),
);

/// Accès à l'app ([authAccess]), null tant que la session ou le verrou ne
/// sont pas connus (démarrage). Une erreur de lecture compte comme une
/// absence : pas de session, pas d'empreinte.
final authAccessProvider = Provider<AuthAccess?>((ref) {
  final session = ref.watch(authUserProvider);
  final lock = ref.watch(biometricLockProvider);
  if (_pending(session) || _pending(lock)) return null;
  return authAccess(
    sessionUid: session.value?.uid,
    lock: lock.value ?? BiometricLock.disabled,
  );
});

bool _pending(AsyncValue<Object?> value) => !value.hasValue && !value.hasError;
