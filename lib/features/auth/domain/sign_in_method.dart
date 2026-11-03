/// Façon dont le compte connecté s'authentifie : décide comment il confirme
/// son identité avant une opération sensible (suppression du compte).
enum SignInMethod { guest, google, email }

/// Méthode d'un compte, d'après Firebase : anonyme, lié à Google
/// ([providerIds] contient `google.com`, invité lié compris), sinon e-mail.
SignInMethod signInMethodOf({
  required bool isAnonymous,
  required Iterable<String> providerIds,
}) {
  if (isAnonymous) return SignInMethod.guest;
  if (providerIds.contains('google.com')) return SignInMethod.google;
  return SignInMethod.email;
}
