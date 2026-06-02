import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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

    HapticFeedback.lightImpact();
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      l10n: context.l10n,
    );

    if (!mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(authState.errorMessage ?? context.l10n.connectionError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  context.l10n.loginTitle,
                  style: textTheme.headlineLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  context.l10n.signInText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 400),
                child: AnKiTextField(
                  controller: _emailController,
                  label: context.l10n.email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authState.isLoading,
                ),
              ),
              const SizedBox(height: 16),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 550),
                child: AnKiTextField(
                  controller: _passwordController,
                  label: context.l10n.password,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  enabled: !authState.isLoading,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 650),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authState.isLoading ? null : () {},
                    child: Text(
                      context.l10n.forgotPassword,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 800),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child:
                          authState.isLoading
                              ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                              : Text(
                                context.l10n.signInButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 950),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.dontHaveAccount,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () => Navigator.of(
                                context,
                              ).pushReplacementNamed('/signup'),
                      child: Text(
                        context.l10n.signUp,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
