import 'dart:async';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (_nameController.text.isEmpty ||
        _surnameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.passwordsDoNotMatch),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    final controller = ref.read(authControllerProvider.notifier);
    // Le profil sera créé par app/bootstrap avec ces noms tels que saisis.
    ref
        .read(signUpNamesProvider.notifier)
        .remember(_nameController.text.trim(), _surnameController.text.trim());

    final success = await controller.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
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
    // Au-delà de 150 % de texte, le prénom et le nom s'empilent plutôt que
    // de couper leurs libellés.
    final stackNames = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    final name = AnKiTextField(
      controller: _nameController,
      label: l10n.firstName,
      prefixIcon: Icons.person_outline_rounded,
      enabled: !isLoading,
    );
    final surname = AnKiTextField(
      controller: _surnameController,
      label: l10n.lastName,
      prefixIcon: Icons.person_outline_rounded,
      enabled: !isLoading,
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
                message: l10n.createAccount,
              ),
              const SizedBox(height: AppSpacing.xl),
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
              AnKiTextField(
                controller: _emailController,
                label: l10n.email,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              AnKiTextField(
                controller: _passwordController,
                label: l10n.password,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                enabled: !isLoading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AnKiTextField(
                controller: _confirmPasswordController,
                label: l10n.confirmPassword,
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirmPassword,
                enabled: !isLoading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthSubmitButton(
                label: l10n.signUpButton,
                loading: isLoading,
                onPressed: _handleSignUp,
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
