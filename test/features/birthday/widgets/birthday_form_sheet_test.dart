import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);

  /// Anniversaire à modifier, avec ou sans photo.
  Birthday editable({Uint8List? picture}) => Birthday(
    id: 'edit-1',
    name: 'Alice',
    surname: 'Wonderland',
    date: const BirthDate(year: 1990, month: 5, day: 10),
    categories: const ['fam'],
    picture: picture,
  );

  List<dynamic> overrides(
    RecordingBirthdayRepository repository, {
    RecordingCategoryRepository? categories,
  }) => [
    clockProvider.overrideWithValue(() => DateTime(2026, 10, 12, 9)),
    currentUidProvider.overrideWithValue('fake-uid'),
    birthdayRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(
      categories ?? RecordingCategoryRepository([family, friend]),
    ),
    userProfileProvider.overrideWithValue(
      const AsyncData(
        UserProfile(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          categories: ['fam', 'fri'],
          locale: 'fr',
        ),
      ),
    ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester,
    RecordingBirthdayRepository repository, {
    Birthday? toEdit,
    String? initialName,
    RecordingCategoryRepository? categories,
  }) => mockNetworkImages(() async {
    await tester.pumpHarness(
      BirthdayFormSheet(birthdayToEdit: toEdit, initialName: initialName),
      overrides: overrides(repository, categories: categories),
    );
    await tester.pumpAndSettle();
  });

  final nameField = find.widgetWithText(TextField, 'Prénom et nom');
  final dateField = find.widgetWithText(TextField, "Date d'anniversaire");

  bool hasFocus(WidgetTester tester, Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  InputDecoration decorationOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).decoration!;

  /// Le bouton principal, « Ajouter » ou « Enregistrer ».
  bool saveEnabled(WidgetTester tester, String label) => tester
      .widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      )
      .enabled;

  group('creation', () {
    testWidgets('opens on the name, keyboard ready', (tester) async {
      await pumpSheet(tester, RecordingBirthdayRepository());

      expect(find.text('Nouvel anniversaire'), findsOneWidget);
      expect(hasFocus(tester, nameField), isTrue);
      expect(find.text("L'année est facultative"), findsOneWidget);
      expect(saveEnabled(tester, 'Ajouter'), isFalse);
    });

    testWidgets('saves with the keyboard alone: name, next, digits, OK', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository);

      await tester.enterText(nameField, 'Léa Martin');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(hasFocus(tester, dateField), isTrue);

      await tester.enterText(dateField, '1203');
      await tester.pump();
      // Les barres s'insèrent pendant la frappe ; l'aperçu dit la date.
      expect(find.text('12/03'), findsOneWidget);
      expect(find.text('Le 12 mars'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayFormSheet), findsNothing);
      expect(repository.created.single.name, 'Léa');
      expect(repository.created.single.surname, 'Martin');
      expect(
        repository.created.single.date,
        const BirthDate(month: 3, day: 12),
      );
    });

    testWidgets('previews the age once the year is typed', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository);

      await tester.enterText(nameField, 'Mamie');
      await tester.enterText(dateField, '12031990');
      await tester.pump();

      expect(find.text('12/03/1990'), findsOneWidget);
      expect(find.text('Le 12 mars 1990 · aura 37 ans'), findsOneWidget);

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      final draft = repository.created.single;
      expect(draft.name, 'Mamie');
      expect(draft.surname, '');
      expect(draft.date, const BirthDate(year: 1990, month: 3, day: 12));
    });

    testWidgets('enables saving only with a name and a date', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository);

      await tester.enterText(nameField, 'Léa');
      await tester.pump();
      expect(saveEnabled(tester, 'Ajouter'), isFalse);

      await tester.enterText(dateField, '1203');
      await tester.pump();
      expect(saveEnabled(tester, 'Ajouter'), isTrue);

      // Un nom effacé, ou fait d'espaces, est signalé.
      await tester.enterText(nameField, '   ');
      await tester.pump();
      expect(saveEnabled(tester, 'Ajouter'), isFalse);
      expect(find.text('Champ obligatoire'), findsOneWidget);

      // « OK » sans nom n'enregistre rien.
      await tester.showKeyboard(dateField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repository.created, isEmpty);
      expect(find.byType(BirthdayFormSheet), findsOneWidget);
    });

    testWidgets('says what is wrong with the date', (tester) async {
      await pumpSheet(tester, RecordingBirthdayRepository());
      await tester.enterText(nameField, 'Léa');

      await tester.enterText(dateField, '3102');
      await tester.pump();
      expect(
        decorationOf(tester, dateField).errorText,
        "Cette date n'existe pas",
      );
      expect(saveEnabled(tester, 'Ajouter'), isFalse);

      await tester.enterText(dateField, '01012030');
      await tester.pump();
      expect(
        decorationOf(tester, dateField).errorText,
        'Cette date est dans le futur',
      );
    });

    testWidgets('flags an unfinished date once the field is left', (
      tester,
    ) async {
      await pumpSheet(tester, RecordingBirthdayRepository());

      // Pendant la frappe, l'aide dit ce qui manque, sans erreur.
      await tester.enterText(dateField, '120319');
      await tester.pump();
      expect(decorationOf(tester, dateField).errorText, isNull);
      expect(
        decorationOf(tester, dateField).helperText,
        "L'année s'écrit avec 4 chiffres",
      );

      await tester.tap(nameField);
      await tester.pumpAndSettle();
      expect(
        decorationOf(tester, dateField).errorText,
        "L'année s'écrit avec 4 chiffres",
      );

      await tester.enterText(dateField, '12');
      await tester.pump();
      expect(decorationOf(tester, dateField).errorText, isNull);
      await tester.tap(nameField);
      await tester.pumpAndSettle();
      expect(
        decorationOf(tester, dateField).errorText,
        'Indiquez le jour et le mois',
      );
    });

    testWidgets('starts at the date when the name comes from a search', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository, initialName: ' Rose  de la Tour ');

      expect(find.text('Rose  de la Tour'), findsOneWidget);
      expect(hasFocus(tester, dateField), isTrue);

      await tester.enterText(dateField, '0101');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository.created.single.name, 'Rose');
      expect(repository.created.single.surname, 'de la Tour');
    });

    testWidgets('picks groups, the check replacing the icon', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository);
      await tester.enterText(nameField, 'Léa');
      await tester.enterText(dateField, '1203');

      expect(find.text('Groupes'), findsOneWidget);
      final familyChip = find.widgetWithText(FilterChip, 'Famille');
      expect(tester.widget<FilterChip>(familyChip).avatar, isNotNull);

      await tester.tap(familyChip);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(familyChip).selected, isTrue);
      expect(tester.widget<FilterChip>(familyChip).avatar, isNull);

      await tester.tap(find.widgetWithText(FilterChip, 'Amis'));
      await tester.tap(find.widgetWithText(FilterChip, 'Amis'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(repository.created.single.categories, ['fam']);
    });

    group('a new group, created in place', () {
      final newGroup = find.widgetWithText(ActionChip, 'Nouveau groupe');
      final groupField = find.widgetWithText(TextField, 'Nom du groupe');

      bool createEnabled(WidgetTester tester) => tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Créer'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .enabled;

      testWidgets('arrives ticked on the person', (tester) async {
        final repository = RecordingBirthdayRepository();
        final categories = RecordingCategoryRepository([family, friend]);
        await pumpSheet(tester, repository, categories: categories);
        await tester.enterText(nameField, 'Léa');
        await tester.enterText(dateField, '1203');

        await tester.tap(newGroup);
        await tester.pumpAndSettle();
        expect(groupField, findsOneWidget);
        // La saisie passe du nom de la personne à celui du groupe.
        expect(hasFocus(tester, groupField), isTrue);
        expect(createEnabled(tester), isFalse);

        await tester.enterText(groupField, 'Voisins');
        await tester.pump();
        expect(createEnabled(tester), isTrue);
        await tester.tap(find.text('Créer'));
        await tester.pumpAndSettle();

        expect(groupField, findsNothing);
        final chip = find.widgetWithText(FilterChip, 'Voisins');
        expect(tester.widget<FilterChip>(chip).selected, isTrue);
        expect(categories.created.single.name, 'Voisins');
        expect(categories.createdFor, ['fake-uid']);

        await tester.tap(find.text('Ajouter'));
        await tester.pumpAndSettle();
        expect(repository.created.single.categories, ['new-cat-1']);
      });

      testWidgets('takes the first free tone, or the one picked', (
        tester,
      ) async {
        final categories = RecordingCategoryRepository([family, friend]);
        await pumpSheet(
          tester,
          RecordingBirthdayRepository(),
          categories: categories,
        );
        await tester.tap(newGroup);
        await tester.pumpAndSettle();

        // Famille et Amis portent le bleu et le vert : l'orange suit.
        expect(
          tester.getSemantics(find.bySemanticsLabel('Orange')),
          isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
        );

        await tester.tap(find.bySemanticsLabel('Violet'));
        await tester.enterText(groupField, 'Voisins');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(categories.created.single.tone, 4);
      });

      testWidgets('refuses a name already taken, accents aside', (
        tester,
      ) async {
        final categories = RecordingCategoryRepository([family, friend]);
        await pumpSheet(
          tester,
          RecordingBirthdayRepository(),
          categories: categories,
        );
        await tester.tap(newGroup);
        await tester.pumpAndSettle();

        await tester.enterText(groupField, ' famillé ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Ce groupe existe déjà'), findsOneWidget);
        expect(createEnabled(tester), isFalse);
        expect(categories.created, isEmpty);
      });

      testWidgets('cancel closes it without creating', (tester) async {
        final categories = RecordingCategoryRepository([family, friend]);
        await pumpSheet(
          tester,
          RecordingBirthdayRepository(),
          categories: categories,
        );
        await tester.tap(newGroup);
        await tester.pumpAndSettle();
        await tester.enterText(groupField, 'Voisins');

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(groupField, findsNothing);
        expect(categories.created, isEmpty);
      });

      testWidgets('keeps labelled 48 dp targets', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSheet(tester, RecordingBirthdayRepository());
        await tester.tap(newGroup);
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    });

    testWidgets('close button is wired', (tester) async {
      await pumpSheet(tester, RecordingBirthdayRepository());

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayFormSheet), findsNothing);
    });
  });

  group('edition', () {
    testWidgets('pre-fills the same sheet and updates', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository, toEdit: editable(picture: _png));

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('10/05/1990'), findsOneWidget);
      expect(find.text('Le 10 mai 1990 · aura 37 ans'), findsOneWidget);
      // La modification n'ouvre pas le clavier.
      expect(hasFocus(tester, nameField), isFalse);

      await tester.enterText(nameField, 'Alice Liddell');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.updated, ['edit-1']);
      final draft = repository.created.single;
      expect(draft.name, 'Alice');
      expect(draft.surname, 'Liddell');
      expect(draft.date, const BirthDate(year: 1990, month: 5, day: 10));
      expect(draft.categories, ['fam']);
      // Photo inchangée : le brouillon n'en apporte pas de nouvelle.
      expect(draft.picture, isNull);
    });

    testWidgets('keeps an unknown year', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(
        tester,
        repository,
        toEdit: const Birthday(
          id: 'mamie',
          name: 'Mamie',
          surname: '',
          date: BirthDate(month: 10, day: 15),
        ),
      );

      expect(find.text('15/10'), findsOneWidget);
      expect(find.text('Le 15 octobre'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        repository.created.single.date,
        const BirthDate(month: 10, day: 15),
      );
    });

    testWidgets('deletes once the undo delay is over', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository, toEdit: editable());

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pumpAndSettle();

      // La feuille se ferme, sans boîte de dialogue ; rien n'est encore effacé.
      expect(find.byType(BirthdayFormSheet), findsNothing);
      expect(
        find.text("Alice Wonderland n'est plus dans vos anniversaires"),
        findsOneWidget,
      );
      expect(repository.deleted, isEmpty);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repository.deleted, ['edit-1']);
    });

    testWidgets('undo keeps the birthday', (tester) async {
      final repository = RecordingBirthdayRepository();
      await pumpSheet(tester, repository, toEdit: editable());

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
    });

    testWidgets('a failed save reaches the editor state', (tester) async {
      final repository = RecordingBirthdayRepository(
        failure: Exception('save failed'),
      );
      await pumpSheet(tester, repository, toEdit: editable());
      // En vrai, l'écran d'accueil écoute l'éditeur et affiche l'erreur.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BirthdayFormSheet)),
      );
      container.listen(birthdayEditorProvider, (_, _) {});

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(container.read(birthdayEditorProvider).hasError, isTrue);
    });
  });

  testWidgets('labels every control for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSheet(tester, RecordingBirthdayRepository(), toEdit: editable());

    expect(
      tester.getSemantics(find.bySemanticsLabel('Choisir une photo')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(find.byTooltip('Supprimer'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('keeps everything whole at 200 % text on a small phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const Center(child: SizedBox(width: 360, child: BirthdayFormSheet())),
        overrides: overrides(RecordingBirthdayRepository()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Léa Martin');
      await tester.enterText(dateField, '12031990');
      await tester.pump();

      expect(find.text('Nouvel anniversaire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
