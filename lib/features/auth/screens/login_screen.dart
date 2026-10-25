import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/sign_in_draft.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/password_reset.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/auth/widgets/auth_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Connexion par e-mail, ouverte depuis la connexion (« Continuer avec un
/// e-mail »), où le retour ramène.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  /// « Mot de passe oublié ? » touché sans adresse : ce qui manque, dit
  /// sous le champ jusqu'à la prochaine frappe.
  bool _resetNeedsEmail = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  SignInDraft get _draft => SignInDraft(
    email: _emailController.text,
    password: _passwordController.text,
  );

  void _refresh() => setState(() {});

  void _handleSignIn() async {
    final draft = _draft;
    if (!draft.isValid) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: draft.email.trim(), password: draft.password);
    if (success && mounted) unawaited(HapticFeedback.lightImpact());
  }

  /// Le lien du mot de passe oublié, vers l'adresse tapée ; sans adresse, le
  /// champ dit ce qui manque et reprend la main.
  void _forgotPassword() {
    if (!_draft.hasEmail) {
      setState(() => _resetNeedsEmail = true);
      _emailFocus.requestFocus();
      return;
    }
    // Le clavier se range : la confirmation paraît à sa place.
    FocusScope.of(context).unfocus();
    unawaited(
      ref
          .read(passwordResetProvider.notifier)
          .send(
            _emailController.text,
            languageCode: Localizations.localeOf(context).languageCode,
          ),
    );
  }

  /// Échec d'une connexion ou de l'envoi du lien, dit de la même façon.
  void _onAuthResult(AsyncValue<Object?>? _, AsyncValue<Object?> next) {
    if (next case AsyncError(:final error)) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErrorMessage(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(authControllerProvider, _onAuthResult)
      ..listen(passwordResetProvider, _onAuthResult);
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );
    final reset = ref.watch(passwordResetProvider);
    final resetSentTo = reset.value;
    final l10n = context.l10n;

    return Scaffold(
      // Le retour vers la connexion, dessous.
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthFormHeader(
                title: l10n.loginTitle,
                message: l10n.loginMessage,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Le gestionnaire de mots de passe remplit les deux champs, et
              // propose d'enregistrer ceux d'une connexion réussie.
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) =>
                          setState(() => _resetNeedsEmail = false),
                      // « Suivant » passe au mot de passe, clavier ouvert,
                      // plutôt qu'à son œil.
                      onEditingComplete: _passwordFocus.requestFocus,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        errorText: _resetNeedsEmail
                            ? l10n.resetPasswordNeedsEmail
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      label: l10n.password,
                      enabled: !isLoading,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _refresh(),
                      // « OK » connecte, comme le bouton.
                      onSubmitted: (_) => _handleSignIn(),
                    ),
                  ],
                ),
              ),
              if (resetSentTo != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ResetLinkSent(
                  email: resetSentTo,
                  // Renvoie à l'adresse tapée, corrigée au besoin.
                  onResend: isLoading || reset.isLoading
                      ? null
                      : _forgotPassword,
                ),
              ] else
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: isLoading || reset.isLoading
                        ? null
                        : _forgotPassword,
                    child: Text(l10n.forgotPassword),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AuthSubmitButton(
                label: l10n.signInButton,
                loading: isLoading,
                // Actif dès que les deux champs sont remplis.
                onPressed: _draft.isValid ? _handleSignIn : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthSwitchPrompt(
                question: l10n.noAccountYet,
                action: l10n.signUp,
                // Remplace la connexion : le retour ramène là d'où elle a
                // été ouverte (bienvenue, connexion).
                onPressed: isLoading
                    ? null
                    : () => context.pushReplacement(AppRoutes.signup),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien du mot de passe oublié parti : vers quelle adresse, que faire
/// ensuite, et de quoi le renvoyer. Annoncé par TalkBack dès qu'il paraît.
class _ResetLinkSent extends StatelessWidget {
  const _ResetLinkSent({required this.email, required this.onResend});

  final String email;

  /// Null : le renvoi est désactivé.
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final success = context.ankiColors.success;

    return Semantics(
      liveRegion: true,
      child: Card(
        color: success.container,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.mark_email_read_rounded,
                      color: success.onContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.resetPasswordSent(email),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: success.onContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.resetPasswordSentHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: success.onContainer,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onResend,
                  style: TextButton.styleFrom(
                    foregroundColor: success.onContainer,
                  ),
                  child: Text(l10n.resetPasswordResend),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
