import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/add_birthday.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_preview.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);
  const hugo = Birthday(
    id: 'hugo',
    name: 'Hugo',
    surname: 'Bernard',
    date: BirthDate(year: 1990, month: 11, day: 17),
  );

  List<dynamic> overrides(
    RecordingBirthdayRepository repository, {
    bool learned = true,
  }) => [
    clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 9)),
    currentUidProvider.overrideWithValue('fake-uid'),
    birthdayRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository([friend]),
    ),
    userProfileProvider.overrideWithValue(
      AsyncData(
        UserProfile(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          locale: 'fr',
          quickAddLearned: learned,
        ),
      ),
    ),
  ];

  /// Un bouton « Ouvrir » qui lance l'ajout comme l'accueil
  /// ([showAddBirthday]) ; il est touché tout de suite.
  Future<void> openAdd(
    WidgetTester tester,
    RecordingBirthdayRepository repository, {
    bool learned = true,
    String? name,
  }) => mockNetworkImages(() async {
    await tester.pumpHarness(
      Consumer(
        builder: (context, ref, _) => Center(
          child: TextButton(
            onPressed: () => showAddBirthday(context, ref, name: name),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      overrides: overrides(repository, learned: learned),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  });

  final field = find.widgetWithText(TextField, 'Qui, et quand ?');

  InputDecoration decoration(WidgetTester tester) =>
      tester.widget<TextField>(field).decoration!;

  bool enabled(WidgetTester tester, String label) {
    final button = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    return tester.widget<ButtonStyleButton>(button.first).enabled;
  }

  /// Un texte de l'aperçu d'une liste collée, pas celui du champ.
  Finder inPreview(String text) => find.descendant(
    of: find.byType(QuickBatchPreview),
    matching: find.textContaining(text, findRichText: true),
  );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  group('showAddBirthday', () {
    testWidgets('opens the full form until a first manual add', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository(), learned: false);

      expect(find.byType(BirthdayFormSheet), findsOneWidget);
      expect(find.byType(QuickAddSheet), findsNothing);
    });

    testWidgets('opens the one-line add once learned', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository());

      expect(find.byType(QuickAddSheet), findsOneWidget);
      expect(find.byType(BirthdayFormSheet), findsNothing);
    });

    testWidgets('starts the line with a searched name', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository(), name: 'Léa');

      expect(tester.widget<TextField>(field).controller!.text, 'Léa ');
    });
  });

  group('one line', () {
    testWidgets('explains the expected line, keyboard ready', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository());

      expect(
        decoration(tester).helperText,
        startsWith('Le prénom puis la date'),
      );
      expect(enabled(tester, 'Ajouter'), isFalse);
      expect(enabled(tester, 'Ajouter et continuer'), isFalse);
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('shows what it understood and adds on Enter', (tester) async {
      final repository = RecordingBirthdayRepository();
      await openAdd(tester, repository);

      await type(tester, 'Hugo Bernard 17 novembre 1990');
      expect(find.text('Hugo Bernard'), findsOneWidget);
      expect(find.text('Le 17 novembre 1990 · aura 36 ans'), findsOneWidget);
      expect(enabled(tester, 'Ajouter'), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(QuickAddSheet), findsNothing);
      final draft = repository.created.single;
      expect((draft.name, draft.surname), ('Hugo', 'Bernard'));
      expect(draft.date, const BirthDate(year: 1990, month: 11, day: 17));
    });

    testWidgets('keeps the groups picked', (tester) async {
      final repository = RecordingBirthdayRepository();
      await openAdd(tester, repository);

      await type(tester, 'Léa 12 mars');
      await tester.tap(find.byType(FilterChip).first);
      await tester.pump();
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(repository.created.single.categories, ['fri']);
    });

    testWidgets('says what is missing, as an error after Enter', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository();
      await openAdd(tester, repository);

      await type(tester, 'Léa');
      expect(
        decoration(tester).helperText,
        'Ajoutez la date, comme « 12 mars »',
      );
      expect(decoration(tester).errorText, isNull);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        decoration(tester).errorText,
        'Ajoutez la date, comme « 12 mars »',
      );
      expect(repository.created, isEmpty);
      expect(find.byType(QuickAddSheet), findsOneWidget);

      await type(tester, '12 mars');
      expect(
        decoration(tester).helperText,
        'Ajoutez le prénom, avant ou après la date',
      );
    });

    testWidgets('says at once that a date does not exist', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository());

      await type(tester, 'Léa 31 avril');

      expect(decoration(tester).errorText, "Cette date n'existe pas");
      expect(enabled(tester, 'Ajouter'), isFalse);
    });

    testWidgets('warns about someone already there, still adds', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(initial: [hugo]);
      await openAdd(tester, repository);

      await type(tester, 'hugo bernard 17/11');

      expect(
        find.text('hugo bernard est déjà dans vos anniversaires à cette date'),
        findsOneWidget,
      );
      expect(enabled(tester, 'Ajouter'), isTrue);
    });

    testWidgets('add and continue clears the line for the next one', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository();
      await openAdd(tester, repository);

      await type(tester, 'Léa 12 mars');
      await tester.tap(find.text('Ajouter et continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickAddSheet), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(decoration(tester).helperText, 'Léa est dans vos anniversaires');

      await type(tester, 'Zoé 1/1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        [for (final draft in repository.created) draft.name],
        ['Léa', 'Zoé'],
      );
      // La feuille l'a dit au fil de l'eau : rien d'empilé derrière elle.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('opens the full form with what it understood', (tester) async {
      await openAdd(tester, RecordingBirthdayRepository());

      await type(tester, 'Léa Martin 12 mars');
      await tester.tap(find.byType(FilterChip).first);
      await tester.pump();
      await tester.tap(find.text('Formulaire complet'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickAddSheet), findsNothing);
      expect(find.byType(BirthdayFormSheet), findsOneWidget);
      expect(find.text('Léa Martin'), findsOneWidget);
      expect(find.text('12/03'), findsOneWidget);
      final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);
      expect(chip.selected, isTrue);
    });
  });

  group('pasted list', () {
    testWidgets('previews each line and adds the new people', (tester) async {
      final repository = RecordingBirthdayRepository(initial: [hugo]);
      await openAdd(tester, repository);

      await type(
        tester,
        'Léa 12 mars\nHugo Bernard 17/11\nTonton Paul\nZoé 1/1',
      );

      expect(find.text('2 personnes à ajouter'), findsOneWidget);
      expect(
        find.textContaining('déjà dans vos anniversaires'),
        findsOneWidget,
      );
      expect(find.textContaining('il manque la date'), findsOneWidget);
      expect(inPreview('Tonton Paul'), findsOneWidget);
      expect(find.text('Formulaire complet'), findsNothing);

      await tester.tap(find.text('Ajouter les 2'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickAddSheet), findsNothing);
      expect(
        [for (final draft in repository.created) draft.name],
        ['Léa', 'Zoé'],
      );
    });

    testWidgets('adds nothing when every line is set aside', (tester) async {
      final repository = RecordingBirthdayRepository(initial: [hugo]);
      await openAdd(tester, repository);

      await type(tester, 'Hugo Bernard 17/11\nTonton Paul\n31/13');

      expect(find.text('Personne à ajouter'), findsOneWidget);
      // Une ligne sans nom se nomme telle que tapée.
      expect(inPreview('31/13'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .enabled,
        isFalse,
      );
    });
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await openAdd(tester, RecordingBirthdayRepository());
    await type(tester, 'Léa 12 mars');

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
