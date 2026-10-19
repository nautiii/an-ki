import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/widgets/guest_backup_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  const title = 'Gardez vos 12 anniversaires';
  const message =
      "Pour l'instant, ils ne sont liés qu'à ce téléphone. Avec votre compte "
      'Google, vous les retrouvez partout.';
  const save = 'Sauvegarder avec Google';
  const takenTitle = 'Ce compte Google a déjà son agenda AnKi';
  const takenMessage =
      'Vos 12 anniversaires restent sur ce téléphone : rien n\'est '
      'perdu. Pour les sauvegarder, choisissez un autre compte Google.';
  const otherAccount = 'Choisir un autre compte';

  /// La carte d'un invité aux 12 anniversaires ; [failure] fait échouer la
  /// liaison.
  Future<FakeAuthRepository> pumpCard(
    WidgetTester tester, {
    Exception? failure,
  }) async {
    final auth = FakeAuthRepository(
      user: MockUser(isAnonymous: true),
      failure: failure,
    );
    await tester.pumpHarness(
      const GuestBackupCard(count: 12),
      overrides: authOverrides(auth),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('invites a guest to keep their birthdays', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester);

    expect(find.text(title), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text(save), findsOneWidget);
    expect(tester.getSemantics(find.text(title)), isSemantics(isHeader: true));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('saves with Google, then says so', (tester) async {
    final auth = await pumpCard(tester);

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(auth.calls, ['linkCurrentUserWithGoogle']);
    expect(auth.currentUser?.isAnonymous, isFalse);
    expect(find.text('Vos 12 anniversaires sont sauvegardés'), findsOneWidget);
  });

  testWidgets('explains a Google account already used by AnKi, and keeps '
      'everything', (tester) async {
    final semantics = tester.ensureSemantics();
    final auth = await pumpCard(
      tester,
      failure: AuthFailure.credentialAlreadyInUse,
    );

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(find.text(takenTitle), findsOneWidget);
    expect(find.text(takenMessage), findsOneWidget);
    expect(find.text(title), findsNothing);
    // L'explication est annoncée à TalkBack dès qu'elle apparaît.
    expect(
      tester.getSemantics(find.text(takenMessage)),
      isSemantics(isLiveRegion: true),
    );
    // L'invité reste invité, sans message de réussite ; le compte Google
    // choisi est oublié, pour en proposer un autre.
    expect(auth.currentUser?.isAnonymous, isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(auth.calls, ['linkCurrentUserWithGoogle', 'signOutGoogle']);

    await tester.tap(find.text(otherAccount));
    await tester.pumpAndSettle();

    expect(auth.calls.where((call) => call == 'linkCurrentUserWithGoogle'), [
      'linkCurrentUserWithGoogle',
      'linkCurrentUserWithGoogle',
    ]);
    expect(find.text(takenTitle), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('says what failed, and lets the guest try again', (tester) async {
    final auth = await pumpCard(tester, failure: AuthFailure.network);

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsOneWidget,
    );
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(auth.calls.where((call) => call == 'linkCurrentUserWithGoogle'), [
      'linkCurrentUserWithGoogle',
      'linkCurrentUserWithGoogle',
    ]);
  });

  testWidgets('a closed Google picker changes nothing', (tester) async {
    await pumpCard(
      tester,
      failure: const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      ),
    );

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('waits while saving', (tester) async {
    await tester.pumpHarness(
      const GuestBackupCard(count: 12),
      overrides: loadingAuthOverrides(),
    );
    await tester.pump();

    final button = find.ancestor(
      of: find.text(save),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
