import 'dart:async';

import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:an_ki/features/birthday/widgets/person_contact_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _lea = Birthday(
  id: 'lea',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(year: 1990, month: 10, day: 24),
);

const _link = ContactLink(number: '06 11 11 11 11', contactName: 'Léa M.');

void main() {
  late FakeContactLinkRepository links;
  late FakePhoneContactService phone;

  setUp(() {
    links = FakeContactLinkRepository();
    phone = FakePhoneContactService();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpHarness(
      const SingleChildScrollView(child: PersonContactSection(birthday: _lea)),
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        contactLinkRepositoryProvider.overrideWithValue(links),
        phoneContactServiceProvider.overrideWithValue(phone),
      ],
    );
    await tester.pump();
  }

  testWidgets('says what AnKi keeps before linking', (tester) async {
    await pump(tester);

    expect(find.text('Relier à un contact'), findsOneWidget);
    expect(
      find.text('Vous choisissez un seul numéro. Il reste sur ce téléphone.'),
      findsOneWidget,
    );
    expect(find.text('Appeler'), findsNothing);
    expect(phone.picks, 0);
  });

  testWidgets('links the number picked, then offers to call and text', (
    tester,
  ) async {
    phone.picked = const PickedPhone(
      number: '06 11 11 11 11',
      contactName: 'Léa M.',
    );
    await pump(tester);

    await tester.tap(find.text('Relier à un contact'));
    await tester.pumpAndSettle();

    expect(links.links['u1'], {'lea': _link});
    expect(find.text('Léa M.'), findsOneWidget);
    expect(find.text('06 11 11 11 11'), findsOneWidget);
    expect(find.text('Numéro gardé sur ce téléphone'), findsOneWidget);

    await tester.tap(find.text('Message'));
    await tester.tap(find.text('Appeler'));
    await tester.pump();
    expect(phone.texts, [('06 11 11 11 11', '')]);
    expect(phone.dialed, ['06 11 11 11 11']);
  });

  testWidgets('a closed picker leaves the person unlinked', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Relier à un contact'));
    await tester.pumpAndSettle();

    expect(links.links, isEmpty);
    expect(find.text('Relier à un contact'), findsOneWidget);
  });

  testWidgets('says when the picker does not open', (tester) async {
    phone.pickError = const PhoneContactUnavailable();
    await pump(tester);

    await tester.tap(find.text('Relier à un contact'));
    await tester.pumpAndSettle();

    expect(
      find.text("Impossible d'ouvrir vos contacts. Réessayez."),
      findsOneWidget,
    );
  });

  testWidgets('says when no app calls or texts', (tester) async {
    links.links['u1'] = {'lea': _link};
    phone.opens = false;
    await pump(tester);

    await tester.tap(find.text('Appeler'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune app pour appeler ou écrire sur ce téléphone.'),
      findsOneWidget,
    );
  });

  testWidgets('unlinks at once, with a way back', (tester) async {
    links.links['u1'] = {'lea': _link};
    await pump(tester);

    await tester.tap(find.byTooltip('Options du contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Délier'));
    await tester.pumpAndSettle();

    expect(links.links['u1'], isNull);
    expect(find.text('Relier à un contact'), findsOneWidget);
    expect(
      find.text('Contact délié : numéro effacé de ce téléphone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(links.links['u1'], {'lea': _link});
    expect(find.text('Léa M.'), findsOneWidget);
  });

  testWidgets('says once when « Annuler » cannot put the link back', (
    tester,
  ) async {
    links.links['u1'] = {'lea': _link};
    await pump(tester);

    await tester.tap(find.byTooltip('Options du contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Délier'));
    await tester.pumpAndSettle();
    links.failure = ContactLinkFailure.storageFailed;
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "La liaison n'a pas pu être mise à jour sur ce téléphone. Réessayez.",
      ),
      findsOneWidget,
    );
    // Une seule snackbar : aucune autre en file derrière.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "La liaison n'a pas pu être mise à jour sur ce téléphone. Réessayez.",
      ),
      findsNothing,
    );
  });

  testWidgets('changes the contact from the menu', (tester) async {
    links.links['u1'] = {'lea': _link};
    phone.picked = const PickedPhone(number: '0699999999', contactName: '');
    await pump(tester);

    await tester.tap(find.byTooltip('Options du contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changer de contact'));
    await tester.pumpAndSettle();

    // Sans nom de contact, le numéro sert de titre.
    expect(find.text('0699999999'), findsOneWidget);
    expect(find.text('Léa M.'), findsNothing);
  });

  testWidgets('shows nothing where phones cannot be linked', (tester) async {
    phone = FakePhoneContactService(isSupported: false);
    await pump(tester);

    expect(find.text('Relier à un contact'), findsNothing);
  });

  testWidgets('shows nothing until the phone storage answers', (tester) async {
    links.links['u1'] = {'lea': _link};
    links.pendingFetch = Completer();
    await pump(tester);

    expect(find.text('Relier à un contact'), findsNothing);
    expect(find.text('Léa M.'), findsNothing);

    links.pendingFetch!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Léa M.'), findsOneWidget);
  });

  testWidgets('waits for the open picker before another tap', (tester) async {
    phone.pendingPick = Completer();
    await pump(tester);

    await tester.tap(find.text('Relier à un contact'));
    await tester.pump();
    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);

    phone.pendingPick!.complete(null);
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isTrue);
  });

  testWidgets('says when the link cannot be saved', (tester) async {
    phone.picked = const PickedPhone(number: '0611111111', contactName: '');
    links.failure = ContactLinkFailure.storageFailed;
    await pump(tester);

    await tester.tap(find.text('Relier à un contact'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "La liaison n'a pas pu être mise à jour sur ce téléphone. Réessayez.",
      ),
      findsOneWidget,
    );
    expect(find.text('Relier à un contact'), findsOneWidget);
  });

  testWidgets('« Annuler » still works once the page is gone', (tester) async {
    links.links['u1'] = {'lea': _link};
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpHarness(
      ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (_, visible, _) => visible
            ? const SingleChildScrollView(
                child: PersonContactSection(birthday: _lea),
              )
            : const SizedBox.shrink(),
      ),
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        contactLinkRepositoryProvider.overrideWithValue(links),
        phoneContactServiceProvider.overrideWithValue(phone),
      ],
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Options du contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Délier'));
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(links.links['u1'], {'lea': _link});
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    await pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('meets the guidelines once linked too', (tester) async {
    links.links['u1'] = {'lea': _link};
    await pump(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
