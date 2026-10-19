/// Quand proposer à un invité de sauvegarder ses anniversaires avec un
/// compte : au moment où son agenda vaut la peine d'être gardé, jamais comme
/// un mur.
abstract final class GuestBackupPolicy {
  /// Nombre d'anniversaires à partir duquel la proposition apparaît.
  static const minBirthdays = 3;
}

/// Nombre d'anniversaires à sauvegarder qu'AnKi annonce à un invité
/// ([guest]) dont l'agenda en compte [birthdays] ; null quand la sauvegarde
/// n'est pas proposée : compte déjà sauvegardé, ou agenda trop mince.
int? guestBackupOffer({required bool guest, required int birthdays}) =>
    guest && birthdays >= GuestBackupPolicy.minBirthdays ? birthdays : null;
