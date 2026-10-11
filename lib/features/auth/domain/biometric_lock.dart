/// Verrou biométrique de l'app.
///
/// Modèle de domaine : Dart pur, immuable. Le verrou ne remplace jamais une
/// session Firebase : il ne fait que déverrouiller celle qui existe. La règle
/// d'accès qui les combine est [authAccess].
class const BiometricLock({
  /// Connexion par empreinte configurée sur l'appareil : capteur disponible
  /// et jeton enregistré. L'app démarre alors verrouillée.
  required final bool enabled,

  /// Verrou passé depuis le démarrage : empreinte, ou connexion explicite.
  final bool unlocked = false,
}) {
  /// Pas de connexion par empreinte : la session Firebase suffit.
  static const disabled = BiometricLock(enabled: false);

  /// Copie modifiée. Un argument null signifie « inchangé ».
  BiometricLock copyWith({bool? enabled, bool? unlocked}) => BiometricLock(
    enabled: enabled ?? this.enabled,
    unlocked: unlocked ?? this.unlocked,
  );

  @override
  bool operator ==(Object other) =>
      other is BiometricLock &&
      other.enabled == enabled &&
      other.unlocked == unlocked;

  @override
  int get hashCode => Object.hash(enabled, unlocked);
}

/// Accès à l'app, qui décide de l'écran affiché.
enum AuthAccess {
  /// Personne n'est connecté : écran de connexion.
  signedOut,

  /// Session ouverte, mais connexion par empreinte configurée et pas encore
  /// passée : écran de connexion, qui propose l'empreinte.
  locked,

  /// L'app s'ouvre.
  granted,
}

/// Règle d'accès. Sans session Firebase, personne n'est connecté, quel que
/// soit le verrou : une session révoquée ne se rouvre pas par l'empreinte, et
/// rien ne s'écrit sans les droits du compte. Avec l'empreinte configurée, la
/// session reste verrouillée tant qu'elle n'a pas été passée.
AuthAccess authAccess({
  required String? sessionUid,
  required BiometricLock lock,
}) {
  if (sessionUid == null) return AuthAccess.signedOut;
  if (lock.enabled && !lock.unlocked) return AuthAccess.locked;
  return AuthAccess.granted;
}
