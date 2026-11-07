import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/settings/widgets/delete_account_tile.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Quentin',
  surname: 'Maillard',
  locale: 'fr',
);

const _deleteError =
    "Le compte n'a pas pu être supprimé. Vérifiez votre connexion et "
    'réessayez.';

void main() {
  late FakeAuthRepository auth;
  late RecordingUserRepository users;

  setUp(() {
    auth = FakeAuthRepository(user: MockUser(uid: 'uid-1'));
    users = RecordingUserRepository(stored: _profile);
  });

  /// Ouvre le dialogue de suppression d'un compte connecté par [method].
  Future<void> openDialog(
    WidgetTester tester, {
    SignInMethod method = SignInMethod.email,
  }) async {
    await tester.pumpHarness(
      const DeleteAccountTile(),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        currentUidProvider.overrideWithValue('uid-1'),
        signInMethodProvider.overrideWithValue(method),
        userRepositoryProvider.overrideWithValue(users),
        birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
        bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository(const []),
        ),
      ],
    );
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() => find.widgetWithText(TextButton, 'Supprimer');

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<TextButton>(button).onPressed != null;

  testWidgets('cancelling erases nothing', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Suppression du compte'), findsNothing);
    expect(users.deleted, isEmpty);
    expect(auth.calls, isEmpty);
  });

  testWidgets('an e-mail account deletes once its password is typed', (
    tester,
  ) async {
    await openDialog(tester);

    expect(
      find.text('Pour confirmer, saisissez votre mot de passe.'),
      findsOne,
    );
    expect(enabled(tester, deleteButton()), isFalse);

    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();
    expect(enabled(tester, deleteButton()), isTrue);

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(auth.reauthPasswords, ['pw']);
    expect(users.deleted, ['uid-1']);
    expect(find.text('Suppression du compte'), findsNothing);
    expect(find.text(_deleteError), findsNothing);
  });

  testWidgets('a wrong password stays in the dialog, under the field', (
    tester,
  ) async {
    auth = FakeAuthRepository(
      user: MockUser(uid: 'uid-1'),
      reauthFailure: AuthFailure.invalidCredentials,
    );
    await openDialog(tester);

    // Envoyé par « OK » du clavier, comme par le bouton.
    await tester.enterText(find.byType(TextField), 'no');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(auth.reauthPasswords, ['no']);
    expect(find.text('Mot de passe incorrect.'), findsOne);
    expect(find.text('Suppression du compte'), findsOne);
    expect(users.deleted, isEmpty);

    // Corrigé, le mot de passe n'est plus marqué refusé.
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();
    expect(find.text('Mot de passe incorrect.'), findsNothing);
  });

  testWidgets('nothing closes the dialog while the deletion runs', (
    tester,
  ) async {
    final gate = Completer<void>();
    auth = FakeAuthRepository(
      user: MockUser(uid: 'uid-1'),
      reauthGate: gate,
    );
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.pump();

    await tester.tap(deleteButton());
    await tester.pump();

    expect(find.bySemanticsLabel('Suppression en cours…'), findsOne);
    expect(enabled(tester, deleteButton()), isFalse);
    expect(
      enabled(tester, find.widgetWithText(TextButton, 'Annuler')),
      isFalse,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.text('Suppression du compte'), findsOne);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Suppression du compte'), findsNothing);
    expect(users.deleted, ['uid-1']);
  });

  testWidgets('a Google account is told its picker comes next', (tester) async {
    await openDialog(tester, method: SignInMethod.google);

    expect(
      find.text(
        'Pour confirmer, Google vous demandera de choisir votre compte.',
      ),
      findsOne,
    );
    expect(find.byType(TextField), findsNothing);

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(auth.calls.first, 'reauthenticateWithGoogle');
    expect(users.deleted, ['uid-1']);
  });

  testWidgets('another Google account is explained', (tester) async {
    auth = FakeAuthRepository(
      user: MockUser(uid: 'uid-1'),
      reauthFailure: AuthFailure.userMismatch,
    );
    await openDialog(tester, method: SignInMethod.google);

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(find.text('Suppression du compte'), findsNothing);
    expect(
      find.text(
        "Ce compte Google n'est pas celui connecté à AnKi. Choisissez le bon "
        'et réessayez.',
      ),
      findsOne,
    );
    expect(users.deleted, isEmpty);
  });

  testWidgets('a refused deletion says the account stays', (tester) async {
    auth = FakeAuthRepository(
      user: MockUser(uid: 'uid-1'),
      deleteFailure: Exception('delete failed'),
    );
    await openDialog(tester, method: SignInMethod.guest);

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(find.text(_deleteError), findsOne);
  });
}
