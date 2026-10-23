import 'dart:async';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
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
  bool _obscurePassword = true;

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
    super.dispose();
  }

  void _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
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
                onPressed: _handleSignIn,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthSwitchPrompt(
                question: l10n.dontHaveAccount,
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
