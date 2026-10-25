/// Moment d'un rappel par rapport à l'anniversaire, en jours de calendrier.
///
/// Vit dans `birthday` : un anniversaire porte son propre réglage
/// (`Birthday.reminders`), que la feature `reminders` planifie.
enum ReminderLead {
  /// Un mois avant, pour un cadeau qui se prépare.
  monthBefore(30),

  /// Une semaine avant.
  weekBefore(7),

  /// La veille.
  dayBefore(1),

  /// Le jour même : toujours prévenu, sauf anniversaire sans rappel.
  sameDay(0);

  const ReminderLead(this.days);

  /// Jours de calendrier avant l'anniversaire.
  final int days;
}
