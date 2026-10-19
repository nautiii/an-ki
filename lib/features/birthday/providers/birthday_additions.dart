import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dernier ajout d'anniversaires fait sur cet appareil (import ou saisie),
/// pour les réactions de l'app : `app/bootstrap` annonce l'import, ou propose
/// les rappels au bon moment. Null jusqu'au premier ajout ; repart de zéro à
/// chaque changement de compte.
class BirthdayAdditions extends Notifier<BirthdaysAdded?> {
  @override
  BirthdaysAdded? build() {
    ref.watch(currentUidProvider);
    return null;
  }

  void record(BirthdaysAdded added) => state = added;

  /// Chaque ajout est un événement, même identique au précédent (deux
  /// imports d'un même nombre de contacts) : `==` ne doit pas le filtrer.
  @override
  bool updateShouldNotify(BirthdaysAdded? previous, BirthdaysAdded? next) =>
      true;
}

final birthdayAdditionsProvider =
    NotifierProvider<BirthdayAdditions, BirthdaysAdded?>(BirthdayAdditions.new);
