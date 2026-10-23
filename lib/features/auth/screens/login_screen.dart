import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/sign_in_draft.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
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
  final _passwordFocus = FocusNode();

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

    unawaited(HapticFeedback.lightImpact());
    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: draft.email.trim(), password: draft.password);
    if (success && mounted) unawaited(HapticFeedback.mediumImpact());
  }

  void _onAuthResult(AsyncValue<void>? _, AsyncValue<void> next) {
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
    ref.listen(authControllerProvider, _onAuthResult);
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );
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
              AuthFormHeader(title: l10n.loginTitle, message: l10n.signInText),
              const SizedBox(height: AppSpacing.xl),
              // Le gestionnaire de mots de passe remplit les deux champs, et
              // propose d'enregistrer ceux d'une connexion réussie.
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => _refresh(),
                      // « Suivant » passe au mot de passe, clavier ouvert,
                      // plutôt qu'à son œil.
                      onEditingComplete: _passwordFocus.requestFocus,
                      decoration: InputDecoration(labelText: l10n.email),
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
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: isLoading ? null : () {},
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
