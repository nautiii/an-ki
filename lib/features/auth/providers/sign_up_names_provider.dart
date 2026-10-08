import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prénom et nom saisis à l'inscription.
typedef SignUpNames = ({String name, String surname});

/// Garde les noms saisis à l'inscription jusqu'à la création du profil par
/// `app/bootstrap`.
///
/// Le nom affiché du compte Firebase (« Jean Pierre Dupont ») ne permet pas de
/// retrouver de façon fiable le prénom composé : on transmet donc la saisie
/// telle quelle, sans que `auth` ait à connaître la feature `user`.
class SignUpNamesNotifier extends Notifier<SignUpNames?> {
  @override
  SignUpNames? build() => null;

  void remember(String name, String surname) =>
      state = (name: name, surname: surname);

  void clear() => state = null;
}

final signUpNamesProvider = NotifierProvider<SignUpNamesNotifier, SignUpNames?>(
  SignUpNamesNotifier.new,
);
