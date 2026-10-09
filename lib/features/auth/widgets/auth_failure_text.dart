import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:flutter/widgets.dart';

/// Message affiché pour un [AuthFailure].
extension AuthFailureText on AuthFailure {
  String message(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      AuthFailure.weakPassword => l10n.errorWeakPassword,
      AuthFailure.emailAlreadyInUse => l10n.errorEmailAlreadyInUse,
      AuthFailure.invalidEmail => l10n.errorInvalidEmail,
      AuthFailure.userNotFound => l10n.errorUserNotFound,
      AuthFailure.wrongPassword => l10n.errorWrongPassword,
      AuthFailure.unknown => l10n.errorUnknown,
      AuthFailure.signUpFailed => l10n.registrationError,
      AuthFailure.signInFailed => l10n.connectionError,
      AuthFailure.googleSignInFailed => l10n.errorGoogleLogin,
      AuthFailure.biometricFailed => l10n.biometricError,
      AuthFailure.signOutFailed => l10n.errorSignOut,
      AuthFailure.deleteAccountFailed => l10n.deleteAccountError,
    };
  }
}
