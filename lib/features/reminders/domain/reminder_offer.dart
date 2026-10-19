import 'package:an_ki/features/birthday/domain/birthdays_added.dart';

/// Ce qui amène à proposer les rappels.
enum ReminderOfferReason {
  /// L'utilisateur vient d'ajouter des anniversaires.
  added,

  /// Une connexion vient de retrouver ses anniversaires sur cet appareil.
  restored,
}

/// Proposition d'activer les rappels, au moment où l'agenda prend de la
/// valeur : [count] anniversaires ajoutés ou retrouvés ([reason]).
class const ReminderOffer({
  required final ReminderOfferReason reason,
  required final int count,
}) {
  @override
  bool operator ==(Object other) =>
      other is ReminderOffer && other.reason == reason && other.count == count;

  @override
  int get hashCode => Object.hash(reason, count);
}

/// Proposition qu'appelle [added], ou null : un import, ou les premiers
/// anniversaires d'un agenda vide. Une saisie de plus à la main ne dérange
/// pas.
ReminderOffer? reminderOfferAfter(BirthdaysAdded added) =>
    added.count > 0 && (added.imported || added.first)
    ? ReminderOffer(reason: ReminderOfferReason.added, count: added.count)
    : null;
