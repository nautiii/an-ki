/// Compte invité que l'utilisateur vient de lier à Google sur cet appareil :
/// même [uid], mêmes données. [displayName] est le nom du compte Google, vide
/// s'il n'en donne pas.
class const GuestLinked({
  required final String uid,
  required final String displayName,
}) {
  @override
  bool operator ==(Object other) =>
      other is GuestLinked &&
      other.uid == uid &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, displayName);
}
