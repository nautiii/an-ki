import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';

import 'fake_providers.dart';

/// Overrides autour d'un faux dépôt d'authentification (qui enregistre les
/// appels) et d'un faux service biométrique.
List<Object> authOverrides(
  FakeAuthRepository repository, {
  FakeBiometricService? biometrics,
}) => [
  authRepositoryProvider.overrideWithValue(repository),
  biometricServiceProvider.overrideWithValue(
    biometrics ?? FakeBiometricService(),
  ),
];

/// Toutes les connexions échouent.
List<Object> failingAuthOverrides() =>
    authOverrides(FakeAuthRepository(failure: AuthFailure.unknown));

/// Une opération est en cours.
List<Object> loadingAuthOverrides() => [
  ...authOverrides(FakeAuthRepository()),
  authControllerProvider.overrideWithBuild(
    (ref, notifier) => Completer<void>().future,
  ),
];
