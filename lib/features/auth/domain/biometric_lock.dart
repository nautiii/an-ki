/// Verrou biométrique de l'app.
///
/// Modèle de domaine : Dart pur, immuable. La règle d'accès qui le combine à
/// la session est [authAccess].
class const BiometricLock({
  /// Connexion par empreinte configurée sur l'appareil : capteur disponible
  /// et jeton enregistré. L'app démarre alors verrouillée.
  required final bool enabled,

  /// Verrou passé depuis le démarrage : empreinte, ou connexion explicite.
  final bool unlocked = false,

  /// Compte ouvert par l'empreinte, qui tient lieu de session quand Firebase
  /// n'en a plus (session biométrique seule, possible hors ligne).
  final String? unlockedUid,
}) {
  /// Pas de connexion par empreinte : la session Firebase suffit.
  static const disabled = BiometricLock(enabled: false);

  /// Copie modifiée. Un argument null signifie « inchangé » ;
  /// `clearUnlockedUid` oublie le compte ouvert par l'empreinte.
  BiometricLock copyWith({
    bool? enabled,
    bool? unlocked,
    String? unlockedUid,
    bool clearUnlockedUid = false,
  }) => BiometricLock(
    enabled: enabled ?? this.enabled,
    unlocked: unlocked ?? this.unlocked,
    unlockedUid: clearUnlockedUid ? null : unlockedUid ?? this.unlockedUid,
  );

  @override
  bool operator ==(Object other) =>
      other is BiometricLock &&
      other.enabled == enabled &&
      other.unlocked == unlocked &&
      other.unlockedUid == unlockedUid;

  @override
  int get hashCode => Object.hash(enabled, unlocked, unlockedUid);
}

/// Accès à l'app, qui décide de l'écran affiché.
enum AuthAccess {
  /// Personne n'est connecté : écran de connexion.
  signedOut,

  /// Connexion par empreinte configurée mais pas encore passée : écran de
  /// connexion, qui propose l'empreinte.
  locked,

  /// L'app s'ouvre.
  granted,
}

/// Règle d'accès. Sans empreinte configurée, la session Firebase suffit ;
/// avec, il faut avoir déverrouillé, puis disposer d'un compte : celui de la
/// session ou, à défaut, celui ouvert par l'empreinte.
AuthAccess authAccess({
  required String? sessionUid,
  required BiometricLock lock,
}) {
  if (!lock.enabled) {
    return sessionUid != null ? AuthAccess.granted : AuthAccess.signedOut;
  }
  if (!lock.unlocked) return AuthAccess.locked;
  return (sessionUid ?? lock.unlockedUid) != null
      ? AuthAccess.granted
      : AuthAccess.signedOut;
}
