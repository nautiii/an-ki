import 'package:an_ki/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthChoicePage extends StatelessWidget {
  const AuthChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'An Ki',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gérez vos anniversaires',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed:
                              authProvider.isLoading
                                  ? null
                                  : () => _handleGoogleSignIn(
                                    context,
                                    authProvider,
                                  ),
                          icon: const Icon(Icons.login),
                          label: const Text('Connexion Google'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed:
                              authProvider.isLoading
                                  ? null
                                  : () =>
                                      Navigator.of(context).pushNamed('/login'),
                          icon: const Icon(Icons.email),
                          label: const Text('Connexion Email'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed:
                              authProvider.isLoading
                                  ? null
                                  : () => _handleAnonymousSignIn(
                                    context,
                                    authProvider,
                                  ),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Continuer sans compte'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Pas encore de compte ? '),
                          TextButton(
                            onPressed:
                                authProvider.isLoading
                                    ? null
                                    : () => Navigator.of(
                                      context,
                                    ).pushNamed('/signup'),
                            child: const Text('S\'inscrire'),
                          ),
                        ],
                      ),
                      if (authProvider.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 24.0),
                          child: CircularProgressIndicator(),
                        ),
                      if (authProvider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Text(
                            authProvider.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGoogleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final success = await authProvider.signInWithGoogle();
    if (!context.mounted) return;

    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
    }
  }

  void _handleAnonymousSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final success = await authProvider.signInAnonymously();
    if (!context.mounted) return;

    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
    }
  }
}
