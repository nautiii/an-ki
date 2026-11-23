/// Liaison d'une personne à un numéro de son répertoire (P5), choisie par
/// l'utilisateur dans le sélecteur du système. Elle ne vit que sur ce
/// téléphone : ni Firestore ni les autres appareils ne la connaissent.
class const ContactLink({
  /// Numéro tel que le répertoire le donne (« 06 12 34 56 78 »).
  required final String number,

  /// Nom du contact dans le répertoire, qui peut différer de celui de la
  /// fiche ; vide s'il n'en a pas.
  required final String contactName,
}) {
  @override
  bool operator ==(Object other) =>
      other is ContactLink &&
      other.number == number &&
      other.contactName == contactName;

  @override
  int get hashCode => Object.hash(number, contactName);
}

/// Liaisons du compte qui reprend un invité, sur ce même téléphone : celles
/// de [target], plus celles de l'invité [guest] reportées sur la fiche qui
/// les reçoit ([keptIds] : fiche de l'invité → fiche du compte, même id pour
/// une fiche reprise, celle gardée pour un doublon). Une fiche déjà liée
/// garde la sienne, une fiche reprise passe avant ses doublons ; une fiche de
/// l'invité absente de [keptIds] perd la sienne.
Map<String, ContactLink> takeOverContactLinks({
  required Map<String, ContactLink> guest,
  required Map<String, ContactLink> target,
  required Map<String, String> keptIds,
}) {
  final links = {...target};
  // Les fiches reprises d'abord, puis les doublons : l'ordre des liaisons
  // enregistrées ne décide de rien.
  for (final moved in [true, false]) {
    for (final MapEntry(key: guestId, value: link) in guest.entries) {
      if (keptIds[guestId] case final keptId?
          when (keptId == guestId) == moved) {
        links.putIfAbsent(keptId, () => link);
      }
    }
  }
  return links;
}
