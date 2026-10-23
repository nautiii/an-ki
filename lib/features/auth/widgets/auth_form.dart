import 'package:an_ki/core/extensions/localization_extension.dart';
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

/// Champ de mot de passe, masqué d'abord : l'œil l'affiche ou le masque, et
/// TalkBack dit ce qu'il fera.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.autofillHints,
    required this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;

  /// `AutofillHints.password` pour se connecter, `newPassword` pour en
  /// créer un : le gestionnaire de mots de passe peut alors en proposer un.
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      // Affiché, le mot de passe ne doit pas être corrigé ni appris.
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
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
