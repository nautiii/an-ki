import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Titre et message en tête d'un formulaire de connexion ou d'inscription.
class AuthFormHeader extends StatelessWidget {
  const AuthFormHeader({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Bouton d'envoi d'un formulaire, au style du thème. Pendant l'attente
/// ([loading]), il se désactive et garde son libellé, que TalkBack lit
/// toujours, une roue à côté.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    this.onPressed,
  });

  final String label;
  final bool loading;

  /// Null : le bouton est désactivé.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: loading ? null : onPressed,
    icon: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    label: Text(label, textAlign: TextAlign.center),
  );
}

/// Une question et l'action qui y répond (« Pas encore de compte ?
/// S'inscrire »), qui passent à la ligne en grand texte au lieu de déborder.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.question,
    required this.action,
    this.onPressed,
  });

  final String question;
  final String action;

  /// Null : l'action est désactivée.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
