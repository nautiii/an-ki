import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/sign_up_draft.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/auth/widgets/auth_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inscription par e-mail, ouverte depuis la connexion, où le retour ramène.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  final _surnameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    // Quitter la confirmation peut faire paraître l'écart des mots de passe.
    _confirmPasswordFocus.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _surnameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  SignUpDraft get _draft => SignUpDraft(
    name: _nameController.text,
    surname: _surnameController.text,
    email: _emailController.text,
    password: _passwordController.text,
    confirmation: _confirmPasswordController.text,
  );

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _handleSignUp() async {
    final draft = _draft;
    if (!draft.isValid) return;

    unawaited(HapticFeedback.lightImpact());
    final controller = ref.read(authControllerProvider.notifier);
    final name = draft.name.trim();
    final surname = draft.surname.trim();
    // Le profil sera créé par app/bootstrap avec ces noms tels que saisis.
    ref.read(signUpNamesProvider.notifier).remember(name, surname);

    final success = await controller.signUp(
      email: draft.email.trim(),
      password: draft.password,
      name: name,
      surname: surname,
    );
    if (success && mounted) unawaited(HapticFeedback.mediumImpact());
  }

  /// Inscription ratée : rien ne doit rester pour une connexion suivante.
  void _onAuthResult(AsyncValue<void>? _, AsyncValue<void> next) {
    if (next case AsyncError(:final error)) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ref.read(signUpNamesProvider.notifier).clear();
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
    final draft = _draft;
    // Au-delà de 150 % de texte, le prénom et le nom s'empilent plutôt que
    // de couper leurs libellés.
    final stackNames = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    final name = TextField(
      controller: _nameController,
      enabled: !isLoading,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      onChanged: (_) => _refresh(),
      onEditingComplete: _surnameFocus.requestFocus,
      decoration: InputDecoration(labelText: l10n.firstName),
    );
    final surname = TextField(
      controller: _surnameController,
      focusNode: _surnameFocus,
      enabled: !isLoading,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      onChanged: (_) => _refresh(),
      onEditingComplete: _emailFocus.requestFocus,
      decoration: InputDecoration(labelText: l10n.lastName),
    );

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
                title: l10n.signUpTitle,
                message: l10n.signUpMessage,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Le gestionnaire de mots de passe peut proposer un mot de
              // passe, puis enregistrer le compte créé.
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (stackNames) ...[
                      name,
                      const SizedBox(height: AppSpacing.md),
                      surname,
                    ] else
                      Row(
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: surname),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => _refresh(),
                      onEditingComplete: _passwordFocus.requestFocus,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      label: l10n.password,
                      enabled: !isLoading,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _refresh(),
                      // « Suivant » passe à la confirmation plutôt qu'à l'œil.
                      onEditingComplete: _confirmPasswordFocus.requestFocus,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      label: l10n.confirmPassword,
                      enabled: !isLoading,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      errorText:
                          draft.confirmationDiffers(
                            typing: _confirmPasswordFocus.hasFocus,
                          )
                          ? l10n.passwordsDoNotMatch
                          : null,
                      onChanged: (_) => _refresh(),
                      // « OK » inscrit, comme le bouton.
                      onSubmitted: (_) => _handleSignUp(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthSubmitButton(
                label: l10n.signUpButton,
                loading: isLoading,
                // Actif dès que tout est rempli, deux fois le même mot de
                // passe.
                onPressed: draft.isValid ? _handleSignUp : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthSwitchPrompt(
                question: l10n.haveAccount,
                action: l10n.signIn,
                // Remplace l'inscription : le retour ramène là d'où elle a
                // été ouverte.
                onPressed: isLoading
                    ? null
                    : () => context.pushReplacement(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
