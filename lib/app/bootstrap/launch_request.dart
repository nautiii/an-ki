import 'package:an_ki/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'une entrée extérieure à l'app demande en l'ouvrant : un toucher de
/// notification, et bientôt un raccourci du lanceur ou le widget d'écran
/// d'accueil. Chaque source se traduit en requête ; `LaunchHandler` les
/// exécute toutes de la même façon, une fois l'app ouverte (connexion et
/// empreinte passées).
@immutable
sealed class const LaunchRequest() {
  /// Requête d'un toucher de notification : « Souhaiter » souhaite la
  /// personne, la notification elle-même ouvre sa page. Null si le toucher
  /// ne nomme aucun anniversaire.
  static LaunchRequest? fromNotification(NotificationTap tap) {
    final birthdayId = tap.payload;
    if (birthdayId == null) return null;
    return tap.actionId == NotificationActions.wish
        ? WishLaunch(birthdayId)
        : PersonLaunch(birthdayId);
  }
}

/// Souhaiter l'anniversaire [birthdayId] : l'accueil, puis la feuille de
/// partage dès que la personne est chargée.
final class const WishLaunch(final String birthdayId) extends LaunchRequest {
  @override
  bool operator ==(Object other) =>
      other is WishLaunch && other.birthdayId == birthdayId;

  @override
  int get hashCode => Object.hash(WishLaunch, birthdayId);
}

/// Ouvrir la page de l'anniversaire [birthdayId] par-dessus l'écran en cours.
final class const PersonLaunch(final String birthdayId) extends LaunchRequest {
  @override
  bool operator ==(Object other) =>
      other is PersonLaunch && other.birthdayId == birthdayId;

  @override
  int get hashCode => Object.hash(PersonLaunch, birthdayId);
}
