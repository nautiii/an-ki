import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthChoicePage extends ConsumerWidget {
  const AuthChoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.manageBirthdays,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () => _handleGoogleSignIn(context, ref),
                      icon: const Icon(Icons.login),
                      label: Text(context.l10n.loginWithGoogle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () => Navigator.of(context).pushNamed('/login'),
                      icon: const Icon(Icons.email),
                      label: Text(context.l10n.loginWithEmail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () => _handleAnonymousSignIn(context, ref),
                      icon: const Icon(Icons.person_outline),
                      label: Text(context.l10n.continueWithoutAccount),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.l10n.noAccountYet),
                      TextButton(
                        onPressed:
                            authState.isLoading
                                ? null
                                : () =>
                                    Navigator.of(context).pushNamed('/signup'),
                        child: Text(context.l10n.signUp),
                      ),
                    ],
                  ),
                  if (authState.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: CircularProgressIndicator(),
                    ),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInWithGoogle();
    if (!context.mounted) return;

    final authState = ref.read(authProvider);
    if (!success && authState.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.errorMessage!)));
    }
  }

  void _handleAnonymousSignIn(BuildContext context, WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInAnonymously();
    if (!context.mounted) return;

    final authState = ref.read(authProvider);
    if (!success && authState.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.errorMessage!)));
    }
  }
}
