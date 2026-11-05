import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/settings/widgets/guest_backup_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

/// Anniversaires dont la reprise échoue, une fois le compte ouvert.
class _FailingTakeOver extends BirthdayRepository {
  _FailingTakeOver(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<void> takeOver(
    String uid, {
    required Map<String, List<String>> moves,
    required Iterable<String> duplicates,
  }) async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );
}

void main() {
  const mergeMessage =
      'Ouvrez-le avec vos 12 anniversaires : ceux qu\'il a déjà ne '
      'seront pas doublés. Vous pouvez aussi choisir un autre compte Google.';
  const open = 'Ouvrir ce compte avec mes 12 anniversaires';
  const title = 'Gardez vos 12 anniversaires';
  const message =
      "Pour l'instant, ils ne sont liés qu'à ce téléphone. Avec votre compte "
      'Google, vous les retrouvez partout.';
  const save = 'Sauvegarder avec Google';
  const takenTitle = 'Ce compte Google a déjà son agenda AnKi';
  const takenMessage =
      'Vos 12 anniversaires restent sur ce téléphone : rien n\'est '
      'perdu. Pour les sauvegarder, choisissez un autre compte Google.';
  const otherAccount = 'Choisir un autre compte';

  /// La carte d'un invité aux 12 anniversaires ; [failure] fait échouer la
  /// liaison. [firestore] porte les données de l'invité et du compte Google.
  Future<FakeAuthRepository> pumpCard(
    WidgetTester tester, {
    Exception? failure,
    FakeFirebaseFirestore? firestore,
  }) async {
    final auth = FakeAuthRepository(
      user: MockUser(uid: 'guest', isAnonymous: true),
      failure: failure,
    );
    await tester.pumpHarness(
      const GuestBackupCard(count: 12),
      overrides: [
        ...authOverrides(auth),
        firestoreProvider.overrideWithValue(
          firestore ?? FakeFirebaseFirestore(),
        ),
      ],
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

  testWidgets('fills its button with the card accent, to stand out from it', (
    tester,
  ) async {
    await pumpCard(tester);

    final tones = tester
        .element(find.byType(GuestBackupCard))
        .ankiColors
        .moonlight;
    final style = tester
        .widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(save),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          ),
        )
        .style;
    expect(style?.backgroundColor?.resolve({}), tones.color);
    expect(style?.foregroundColor?.resolve({}), tones.onColor);
  });

  testWidgets('saves with Google, then says so', (tester) async {
    final auth = await pumpCard(tester);

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOutGoogle', 'linkCurrentUserWithGoogle']);
    expect(auth.currentUser?.isAnonymous, isFalse);
    expect(find.text('Vos 12 anniversaires sont sauvegardés'), findsOneWidget);
  });

  testWidgets('offers to open a Google account AnKi knows, or to choose '
      'another, and keeps everything', (tester) async {
    final semantics = tester.ensureSemantics();
    final auth = await pumpCard(
      tester,
      failure: AuthFailure.credentialAlreadyInUse,
    );

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(find.text(takenTitle), findsOneWidget);
    expect(find.text(mergeMessage), findsOneWidget);
    expect(find.text(open), findsOneWidget);
    expect(find.text(otherAccount), findsOneWidget);
    expect(find.text(title), findsNothing);
    // L'explication est annoncée à TalkBack dès qu'elle apparaît.
    expect(
      tester.getSemantics(find.text(mergeMessage)),
      isSemantics(isLiveRegion: true),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    // L'invité reste invité, sans message de réussite ; le compte Google
    // choisi reste connu, pour l'ouvrir sans sélecteur.
    expect(auth.currentUser?.isAnonymous, isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(auth.calls, ['signOutGoogle', 'linkCurrentUserWithGoogle']);

    await tester.tap(find.text(otherAccount));
    await tester.pumpAndSettle();

    expect(auth.calls.where((call) => call == 'linkCurrentUserWithGoogle'), [
      'linkCurrentUserWithGoogle',
      'linkCurrentUserWithGoogle',
    ]);
    expect(find.text(takenTitle), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an address that is an e-mail account only offers another '
      'Google account', (tester) async {
    await pumpCard(tester, failure: AuthFailure.emailAlreadyInUse);

    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    expect(find.text(takenTitle), findsOneWidget);
    expect(find.text(takenMessage), findsOneWidget);
    expect(find.text(open), findsNothing);
    expect(find.text(otherAccount), findsOneWidget);
  });

  testWidgets('opens the Google account with the birthdays, then says so', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    Future<void> seed(String id, String uid, String name, int month) =>
        firestore.collection('birthday').doc(id).set({
          'uid': uid,
          'name': name,
          'surname': '',
          'date': Timestamp.fromDate(DateTime(2000, month, 9)),
          'yearKnown': false,
        });
    await seed('b1', 'guest', 'Tom', 2);
    await seed('b2', 'guest', 'Léa', 10);
    await seed('t1', FakeAuthRepository.googleUid, 'Léa', 10);
    final auth = await pumpCard(
      tester,
      failure: AuthFailure.credentialAlreadyInUse,
      firestore: firestore,
    );
    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    await tester.tap(find.text(open));
    await tester.pumpAndSettle();

    expect(auth.currentUser?.uid, FakeAuthRepository.googleUid);
    expect(
      find.text('1 anniversaire ajouté à ce compte · 1 y était déjà'),
      findsOneWidget,
    );
    final tom = await firestore.collection('birthday').doc('b1').get();
    expect(tom.data()?['uid'], FakeAuthRepository.googleUid);
  });

  testWidgets('a picker closed for another account drops the offer to open '
      'the first one', (tester) async {
    final auth = await pumpCard(
      tester,
      failure: AuthFailure.credentialAlreadyInUse,
    );
    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    auth.failure = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await tester.tap(find.text(otherAccount));
    await tester.pumpAndSettle();

    // Le compte retenu est oublié : la carte revient à son offre.
    expect(find.text(open), findsNothing);
    expect(find.text(title), findsOneWidget);
    expect(find.text(save), findsOneWidget);
  });

  group('when the birthdays do not follow the opened account', () {
    Future<void> openWithFailingTakeOver(
      WidgetTester tester, {
      required bool removedWithTheGuest,
    }) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('birthday').doc('b1').set({
        'uid': 'guest',
        'name': 'Tom',
        'surname': '',
        'date': Timestamp.fromDate(DateTime(2000, 2, 9)),
      });
      final auth = FakeAuthRepository(
        user: MockUser(uid: 'guest', isAnonymous: true),
        failure: AuthFailure.credentialAlreadyInUse,
      );
      await tester.pumpHarness(
        Consumer(
          builder: (_, ref, _) =>
              !removedWithTheGuest || ref.watch(isGuestProvider)
              ? const GuestBackupCard(count: 12)
              : const SizedBox.shrink(),
        ),
        overrides: [
          ...authOverrides(auth),
          firestoreProvider.overrideWithValue(firestore),
          birthdayRepositoryProvider.overrideWithValue(
            _FailingTakeOver(firestore),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(save));
      await tester.pumpAndSettle();

      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
    }

    const incomplete =
        "Compte ouvert, mais vos anniversaires n'ont pas pu y être ajoutés.";

    testWidgets('says so while the card is still there', (tester) async {
      await openWithFailingTakeOver(tester, removedWithTheGuest: false);

      expect(find.text(incomplete), findsOneWidget);
      // Rien à réessayer ici : l'invité n'est plus.
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('says so once the card left with the guest', (tester) async {
      await openWithFailingTakeOver(tester, removedWithTheGuest: true);

      expect(find.byType(GuestBackupCard), findsNothing);
      expect(find.text(incomplete), findsOneWidget);
    });
  });

  testWidgets('says why the account did not open, and keeps the offer', (
    tester,
  ) async {
    final auth = await pumpCard(
      tester,
      failure: AuthFailure.credentialAlreadyInUse,
    );
    auth.googleAccountFailure = AuthFailure.network;
    await tester.tap(find.text(save));
    await tester.pumpAndSettle();

    await tester.tap(find.text(open));
    await tester.pumpAndSettle();

    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsOneWidget,
    );
    expect(find.text(open), findsOneWidget);
    expect(auth.currentUser?.uid, 'guest');
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
