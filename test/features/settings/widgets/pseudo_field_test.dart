import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/settings/widgets/pseudo_field.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Camille',
  surname: 'Durand',
  pseudo: 'Cam',
  locale: 'fr',
);

void main() {
  /// Le champ dans une page, comme dans les réglages, sur un profil chargé
  /// dont le dépôt reflète chaque écriture.
  Future<RecordingUserRepository> pumpField(
    WidgetTester tester, {
    UserProfile profile = _profile,
  }) async {
    final users = RecordingUserRepository(stored: profile);
    await tester.pumpHarness(
      const Scaffold(body: PseudoField()),
      overrides: [
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue('uid-1'),
      ],
    );
    // Comme dans l'app : le profil est là quand les réglages s'ouvrent.
    await tester.pumpAndSettle();
    return users;
  }

  Finder check() => find.byTooltip('Enregistrer le pseudo');

  testWidgets('starts from the saved pseudo, without a check', (tester) async {
    await pumpField(tester);

    expect(find.text('Cam'), findsOneWidget);
    expect(find.text('Le nom qui vous salue sur l\'accueil'), findsOneWidget);
    expect(check(), findsNothing);
  });

  testWidgets('the check saves a changed pseudo', (tester) async {
    final users = await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'Camou');
    await tester.pump();
    expect(check(), findsOneWidget);

    await tester.tap(check());
    await tester.pumpAndSettle();

    expect(users.stored?.pseudo, 'Camou');
    expect(find.text('Pseudo enregistré'), findsOneWidget);
    expect(check(), findsNothing);
  });

  testWidgets('the keyboard OK saves too, trimmed', (tester) async {
    final users = await pumpField(tester);

    await tester.enterText(find.byType(TextField), '  Camou ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(users.stored?.pseudo, 'Camou');
  });

  testWidgets('an emptied pseudo is cleared', (tester) async {
    final users = await pumpField(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(users.stored?.pseudo, '');
  });

  testWidgets('an unchanged pseudo writes nothing', (tester) async {
    final users = await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'Cam ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(users.updated, isEmpty);
    expect(find.text('Pseudo enregistré'), findsNothing);
  });

  testWidgets('a profile without pseudo starts empty', (tester) async {
    await pumpField(
      tester,
      profile: const UserProfile(
        id: 'uid-1',
        name: 'Camille',
        surname: 'Durand',
        locale: 'fr',
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('keeps a labelled 48 dp check', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'Camou');
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('follows a pseudo saved elsewhere until edited here', (
    tester,
  ) async {
    final users = await pumpField(tester);

    await users.updatePreferences('uid-1', pseudo: 'Mimi');
    await tester.pumpAndSettle();
    expect(find.text('Mimi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Camou');
    await users.updatePreferences('uid-1', pseudo: 'Lou');
    await tester.pumpAndSettle();
    expect(find.text('Camou'), findsOneWidget);
  });
}
