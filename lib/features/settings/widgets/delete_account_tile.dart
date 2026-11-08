import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/auth/widgets/auth_form.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « Supprimer mon compte », seule ligne à la couleur d'erreur : un dialogue
/// nomme la conséquence et fait confirmer l'identité avant d'effacer les
/// données puis le compte.
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(Icons.delete_forever_rounded, color: error),
      title: Text(context.l10n.deleteAccount, style: TextStyle(color: error)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _DeleteAccountDialog(),
      ),
    );
  }
}

/// Confirmation de la suppression : un compte e-mail saisit son mot de passe,
/// un compte Google est prévenu que son sélecteur va s'ouvrir. Le dialogue
/// reste ouvert pendant l'opération (rien ne le ferme alors) ; réussie, le
/// routeur l'emporte avec la page vers la bienvenue ; il ne se ferme lui-même
/// que sur un échec ou une annulation. Un mot de passe refusé s'affiche sous
/// le champ, tout autre échec dans une snackbar.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  String? _passwordError;

  /// Compte supprimé : plus rien à confirmer, en attendant que le routeur
  /// emporte le dialogue.
  bool _deleted = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(SignInMethod? method) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await ref
        .read(accountDeletionProvider.notifier)
        .deleteAccount(
          password: method == SignInMethod.email ? _password.text : null,
        );
    // Compte supprimé : la session fermée, le routeur part vers la bienvenue
    // et emporte ce dialogue. Le fermer ici dépilerait la bienvenue, déjà
    // en place, et laisserait un écran vide.
    if (!mounted) return;
    if (deleted) {
      setState(() => _deleted = true);
      return;
    }
    final error = ref.read(accountDeletionProvider).error;
    if (error == AuthFailure.wrongPassword ||
        error == AuthFailure.invalidCredentials) {
      setState(() => _passwordError = context.l10n.deleteAccountWrongPassword);
      return;
    }
    final message = switch (error) {
      null => null,
      AuthFailure() when error != AuthFailure.deleteAccountFailed =>
        authErrorMessage(context, error),
      _ => context.l10n.deleteAccountError,
    };
    // Seulement s'il est encore au-dessus : sinon `pop` fermerait l'écran
    // d'en dessous.
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final method = ref.watch(signInMethodProvider);
    // Regardé aussi pour garder le contrôleur en vie pendant l'opération.
    final loading = ref.watch(accountDeletionProvider).isLoading;
    // Pendant l'opération, puis une fois le compte supprimé : plus rien à
    // toucher.
    final busy = loading || _deleted;
    final needsPassword = method == SignInMethod.email;
    final canDelete = !busy && (!needsPassword || _password.text.isNotEmpty);

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteAccountConfirmation),
              if (method == SignInMethod.google) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.deleteAccountGooglePrompt),
              ],
              if (needsPassword) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.deleteAccountPasswordPrompt),
                const SizedBox(height: AppSpacing.xs),
                PasswordField(
                  controller: _password,
                  label: l10n.password,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  enabled: !busy,
                  errorText: _passwordError,
                  onChanged: (_) => setState(() => _passwordError = null),
                  onSubmitted: canDelete ? (_) => _delete(method) : null,
                ),
              ],
              if (loading) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  semanticsLabel: l10n.deleteAccountInProgress,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: canDelete ? () => _delete(method) : null,
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
