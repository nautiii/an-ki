import 'dart:async';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/birthday/screens/contact_import_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _lea = ImportedBirthday(
  name: 'Léa',
  surname: 'Martin',
  month: 3,
  day: 12,
  year: 1990,
);
const _hugo = ImportedBirthday(
  name: 'Hugo',
  surname: 'Bernard',
  month: 10,
  day: 15,
);

const _savedLea = Birthday(
  id: 'b1',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(year: 1990, month: 3, day: 12),
);

void main() {
  late RecordingBirthdayRepository repository;

  /// L'écran d'import d'une session ouverte, le lundi 12 octobre 2026 ;
  /// AnKi connaît déjà [existing].
  Future<void> pumpImport(
    WidgetTester tester,
    FakeContactsService contacts, {
    List<Birthday> existing = const [],
  }) async {
    repository = RecordingBirthdayRepository(initial: existing);
    await tester.pumpHarness(
      const ContactImportScreen(),
      overrides: [
        contactsServiceProvider.overrideWithValue(contacts),
        birthdayRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository(const []),
        ),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserProfile(
              id: 'fake-uid',
              name: 'Camille',
              surname: 'Durand',
              locale: 'fr',
            ),
          ),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 12, 9)),
      ],
    );
    await tester.pumpAndSettle();
  }

  FilledButton addButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.textContaining('Ajouter'),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('asks for access on arrival, then previews everyone ticked', (
    tester,
  ) async {
    final contacts = FakeContactsService(contacts: const [_lea, _hugo]);
    await pumpImport(tester, contacts);

    expect(contacts.requests, 1);
    expect(
      find.text(
        '2 anniversaires trouvés. '
        'Décochez ceux que vous ne voulez pas suivre.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tout cocher (2)'), findsOneWidget);
    // Le plus proche d'abord : Hugo dans 3 jours, Léa en mars.
    final hugo = tester.getTopLeft(find.text('Hugo Bernard')).dy;
    expect(hugo, lessThan(tester.getTopLeft(find.text('Léa Martin')).dy));
    expect(find.text('15 octobre · dans 3 jours'), findsOneWidget);
    expect(find.text('Ajouter 2 anniversaires'), findsOneWidget);
  });

  testWidgets('shows whoever AnKi has apart, with nothing to tick', (
    tester,
  ) async {
    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea, _hugo]),
      existing: [_savedLea],
    );

    expect(find.text('Déjà dans AnKi'), findsOneWidget);
    expect(find.text('Léa Martin'), findsOneWidget);
    // « Tout cocher » et Hugo : Léa n'a pas de case.
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('Ajouter 1 anniversaire'), findsOneWidget);
  });

  testWidgets('counts the ticked contacts, and adds nothing without one', (
    tester,
  ) async {
    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea, _hugo]),
    );

    await tester.tap(find.text('Hugo Bernard'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter 1 anniversaire'), findsOneWidget);

    await tester.tap(find.text('Tout cocher (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter 2 anniversaires'), findsOneWidget);

    await tester.tap(find.text('Tout cocher (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
  });

  testWidgets('adds the ticked contacts, reports them and closes', (
    tester,
  ) async {
    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea, _hugo]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContactImportScreen)),
    );

    await tester.tap(find.text('Léa Martin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter 1 anniversaire'));
    await tester.pumpAndSettle();

    expect(repository.created.map((draft) => draft.fullName), ['Hugo Bernard']);
    expect(find.byType(ContactImportScreen), findsNothing);
    // L'app l'annonce (`ReminderPrompt`) : un message, ou les rappels.
    expect(
      container.read(birthdayAdditionsProvider),
      const BirthdaysAdded(count: 1, imported: true, first: true),
    );
  });

  testWidgets('all known: says so and adds nothing', (tester) async {
    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea]),
      existing: [_savedLea],
    );

    expect(
      find.text('Tous les anniversaires de vos contacts sont déjà dans AnKi.'),
      findsOneWidget,
    );
    expect(find.text('Tout cocher (0)'), findsNothing);
    // Rien à ajouter : pas de bouton grisé, la croix ferme.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(CloseButton), findsOneWidget);
  });

  testWidgets('denied: explains, then asks again', (tester) async {
    final contacts = FakeContactsService(
      access: ContactsAccess.denied,
      contacts: const [_hugo],
    );
    await pumpImport(tester, contacts);

    expect(find.text("AnKi n'a pas accès à vos contacts"), findsOneWidget);
    expect(
      find.text(
        "Autorisez l'accès pour choisir qui ajouter, "
        'ou ajoutez vos proches à la main.',
      ),
      findsOneWidget,
    );

    contacts.access = ContactsAccess.granted;
    await tester.tap(find.text("Autoriser l'accès"));
    await tester.pumpAndSettle();

    expect(contacts.requests, 2);
    expect(find.text('Hugo Bernard'), findsOneWidget);
  });

  testWidgets('blocked: opens the settings, then reloads on return', (
    tester,
  ) async {
    final contacts = FakeContactsService(
      access: ContactsAccess.blocked,
      contacts: const [_hugo],
    );
    await pumpImport(tester, contacts);

    await tester.tap(find.text('Ouvrir les réglages'));
    await tester.pumpAndSettle();
    expect(contacts.settingsOpened, 1);

    // L'utilisateur autorise « Contacts » dans les réglages, puis revient.
    contacts.access = ContactsAccess.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Hugo Bernard'), findsOneWidget);
    // Relu de lui-même au retour : l'accès vérifié d'abord, puis lu.
    expect(contacts.requests, 2);
  });

  testWidgets('no birthday in the contacts: add one by hand', (tester) async {
    await pumpImport(tester, FakeContactsService());

    expect(find.text('Aucun anniversaire dans vos contacts'), findsOneWidget);

    await tester.tap(find.text('Ajouter à la main'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactImportScreen), findsNothing);
    expect(find.byType(BirthdayFormSheet), findsOneWidget);
  });

  testWidgets('unreadable contacts: says so and tries again', (tester) async {
    final contacts = FakeContactsService(
      failure: PlatformException(code: 'failed'),
    );
    await pumpImport(tester, contacts);

    expect(find.text('Impossible de lire vos contacts'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(contacts.reads, 2);
  });

  testWidgets('shows skeleton rows while reading', (tester) async {
    final contacts = FakeContactsService(contacts: const [_hugo])
      ..pendingRead = Completer<void>();
    await tester.pumpHarness(
      const ContactImportScreen(),
      overrides: [
        contactsServiceProvider.overrideWithValue(contacts),
        birthdayRepositoryProvider.overrideWithValue(
          RecordingBirthdayRepository(),
        ),
        currentUidProvider.overrideWithValue('fake-uid'),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 12, 9)),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);

    contacts.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Hugo Bernard'), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea, _hugo]),
      existing: [_savedLea],
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds together on a small phone at 200 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpImport(
      tester,
      FakeContactsService(contacts: const [_lea, _hugo]),
      existing: [_savedLea],
    );
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
