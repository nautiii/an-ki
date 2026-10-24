import 'dart:async';

import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lien du mot de passe oublié (ViewModel de la connexion par e-mail), à
/// part des connexions : « Se connecter » ne tourne pas pendant l'envoi.
///
/// État : l'adresse où le dernier lien est parti, null avant ; `AsyncLoading`
/// pendant l'envoi (qui garde la précédente) ; `AsyncError` portant un
/// [AuthFailure] s'il échoue. Repart de zéro à chaque ouverture de l'écran.
class PasswordReset extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  /// Envoie le lien à [email], sans les espaces autour, rédigé dans la langue
  /// [languageCode] de l'app ; renvoie true s'il est parti. Un appel pendant
  /// un envoi est ignoré.
  Future<bool> send(String email, {required String languageCode}) async {
    if (state.isLoading) return false;
    final address = email.trim();
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.sendPasswordReset(address, languageCode: languageCode);
      if (ref.mounted) state = AsyncData(address);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(
          error is AuthFailure ? error : AuthFailure.passwordResetFailed,
          stackTrace,
        );
      }
      return false;
    }
  }
}

final passwordResetProvider =
    AsyncNotifierProvider.autoDispose<PasswordReset, String?>(
      PasswordReset.new,
    );
