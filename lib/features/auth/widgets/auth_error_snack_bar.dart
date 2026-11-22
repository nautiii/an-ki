import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter/material.dart';

/// Annonce l'échec [error] d'une opération d'authentification : snackbar sur
/// le fond d'erreur du thème, texte en `onError` pour rester lisible de jour
/// comme de nuit (le texte par défaut d'une snackbar suit `onInverseSurface`).
void showAuthErrorSnackBar(BuildContext context, Object error) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        authErrorMessage(context, error),
        style: TextStyle(color: colorScheme.onError),
      ),
      backgroundColor: colorScheme.error,
    ),
  );
}
