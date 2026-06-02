import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
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
          behavior: SnackBarBehavior.floating,
          content: Text(context.l10n.passwordsDoNotMatch),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final authNotifier = ref.read(authProvider.notifier);
    final userNotifier = ref.read(userProvider.notifier);

    final success = await authNotifier.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      l10n: context.l10n,
    );

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (success && authState.user != null) {
      HapticFeedback.mediumImpact();
      await userNotifier.createUser(
        uid: authState.user!.uid,
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
      );
    } else if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            authState.errorMessage ?? context.l10n.registrationError,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
                  context.l10n.signUpTitle,
                  style: textTheme.headlineLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  context.l10n.createAccount,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Expanded(
                      child: AnKiTextField(
                        controller: _nameController,
                        label: context.l10n.firstName,
                        prefixIcon: Icons.person_outline_rounded,
                        enabled: !authState.isLoading,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnKiTextField(
                        controller: _surnameController,
                        label: context.l10n.lastName,
                        prefixIcon: Icons.person_outline_rounded,
                        enabled: !authState.isLoading,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 500),
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
                delay: const Duration(milliseconds: 600),
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
              const SizedBox(height: 16),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 700),
                child: AnKiTextField(
                  controller: _confirmPasswordController,
                  label: context.l10n.confirmPassword,
                  prefixIcon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirmPassword,
                  enabled: !authState.isLoading,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 850),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleSignUp,
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
                                context.l10n.signUpButton,
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
                delay: const Duration(milliseconds: 1000),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.haveAccount,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () => Navigator.of(
                                context,
                              ).pushReplacementNamed('/login'),
                      child: Text(
                        context.l10n.signIn,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
