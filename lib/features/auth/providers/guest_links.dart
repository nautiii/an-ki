import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dernière liaison d'un compte invité à Google faite pendant cette exécution
/// de l'app, pour les réactions de l'app : `app/bootstrap` reprend les noms du
/// compte Google sur le profil, sans que `auth` connaisse la feature `user`.
/// Null jusqu'à la première liaison.
class GuestLinks extends Notifier<GuestLinked?> {
  @override
  GuestLinked? build() => null;

  void record(GuestLinked linked) => state = linked;

  /// Chaque liaison est un événement, même identique à la précédente :
  /// `==` ne doit pas la filtrer.
  @override
  bool updateShouldNotify(GuestLinked? previous, GuestLinked? next) => true;
}

final guestLinksProvider = NotifierProvider<GuestLinks, GuestLinked?>(
  GuestLinks.new,
);
