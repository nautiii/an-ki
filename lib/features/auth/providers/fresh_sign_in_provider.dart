import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compte ouvert par une connexion explicite (e-mail, Google, inscription,
/// « Commencer ») pendant cette exécution de l'app ; null pour une session
/// restaurée au démarrage ou déverrouillée par l'empreinte.
///
/// Sur un nouvel appareil, l'agenda d'un compte qui revient arrive avec
/// cette connexion : `app/bootstrap` y propose les rappels, sans que `auth`
/// connaisse la feature `reminders`.
class FreshSignIn extends Notifier<String?> {
  @override
  String? build() => null;

  void record(String uid) => state = uid;
}

final freshSignInProvider = NotifierProvider<FreshSignIn, String?>(
  FreshSignIn.new,
);
