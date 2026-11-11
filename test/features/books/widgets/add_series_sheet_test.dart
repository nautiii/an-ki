import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/widgets/add_series_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  late RecordingBookshelfRepository repository;

  /// L'id renvoyé par la feuille, une fois fermée.
  String? returned;
  var closed = false;

  Future<void> openSheet(WidgetTester tester) async {
    returned = null;
    closed = false;
    repository = RecordingBookshelfRepository(
      series: const [
        Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: false,
        ),
      ],
    );
    await tester.pumpHarness(
      // L'étagère est chargée avant la feuille, comme sur ses écrans.
      Consumer(
        builder: (context, ref, _) {
          ref.watch(shelfProvider);
          return TextButton(
            onPressed: () async {
              returned = await AddSeriesSheet.show(context);
              closed = true;
            },
            child: const Text('Ouvrir'),
          );
        },
      ),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.widgetWithText(TextField, 'Nom de la série');
  Finder volumesField() => find.widgetWithText(TextField, "J'ai les tomes");

  FilledButton addButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Ajouter'));

  testWidgets('"Ajouter" is disabled until a name and valid volumes', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('Ajouter une série'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    await tester.enterText(nameField(), 'Blacksad');
    await tester.pump();
    expect(addButton(tester).onPressed, isNull);

    await tester.enterText(volumesField(), 'abc');
    await tester.pump();
    expect(addButton(tester).onPressed, isNull);

    await tester.enterText(volumesField(), '1-3');
    await tester.pump();
    expect(addButton(tester).onPressed, isNotNull);

    await tester.enterText(nameField(), '  ');
    await tester.pump();
    expect(addButton(tester).onPressed, isNull);
  });

  testWidgets('shows each typed error inline, after typing only', (
    tester,
  ) async {
    await openSheet(tester);
    expect(
      find.text('Des numéros à partir de 1, comme 1-12, 15'),
      findsNothing,
    );

    await tester.enterText(volumesField(), 'abc');
    await tester.pump();
    expect(
      find.text('Des numéros à partir de 1, comme 1-12, 15'),
      findsOneWidget,
    );

    await tester.enterText(volumesField(), '12-1');
    await tester.pump();
    expect(
      find.text('Une plage va du plus petit au plus grand : 1-12'),
      findsOneWidget,
    );

    await tester.enterText(volumesField(), '5000');
    await tester.pump();
    expect(find.text("Un numéro jusqu'à $maxVolumeNumber"), findsOneWidget);

    await tester.enterText(volumesField(), '');
    await tester.pump();
    expect(find.text('Indiquez au moins un tome'), findsOneWidget);
  });

  testWidgets('a name left empty after typing shows its error', (tester) async {
    await openSheet(tester);

    await tester.enterText(nameField(), 'a');
    await tester.enterText(nameField(), '');
    await tester.pump();

    expect(find.text('Donnez un nom à la série'), findsOneWidget);
  });

  testWidgets('suggests an existing series and joins it when picked', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(nameField(), 'One');
    await tester.pump();
    final chip = find.widgetWithText(ActionChip, 'One Piece');
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump();

    expect(tester.widget<TextField>(nameField()).controller?.text, 'One Piece');
    expect(find.text('Ajoutés à votre série « One Piece »'), findsOneWidget);
    // Une fois la série rejointe, plus de suggestion.
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('the "Série terminée" switch toggles', (tester) async {
    await openSheet(tester);
    Switch toggle() => tester.widget(find.byType(Switch));
    expect(find.text('Série terminée'), findsOneWidget);
    expect(toggle().value, isFalse);

    await tester.tap(find.text('Série terminée'));
    await tester.pump();

    expect(toggle().value, isTrue);
  });

  testWidgets('saves a complete series with its volumes and closes', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(nameField(), 'Blacksad');
    await tester.enterText(volumesField(), '1-3, 5');
    await tester.tap(find.text('Série terminée'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(find.byType(AddSeriesSheet), findsNothing);
    expect(closed, isTrue);
    expect(returned, 'series-0');
    final created = repository.createdSeries.single;
    expect((created.name, created.complete), ('Blacksad', true));
    expect(repository.volumes.map((v) => v.number), [1, 2, 3, 5]);
    expect(repository.volumes.every((v) => v.seriesId == 'series-0'), isTrue);
  });

  testWidgets('submitting from the keyboard saves too', (tester) async {
    await openSheet(tester);

    await tester.enterText(nameField(), 'Blacksad');
    await tester.enterText(volumesField(), '2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(returned, 'series-0');
    expect(repository.volumes.single.number, 2);
  });

  testWidgets('joining an existing series creates no series', (tester) async {
    await openSheet(tester);

    await tester.enterText(nameField(), 'one piece');
    await tester.enterText(volumesField(), '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(returned, 's1');
    expect(repository.createdSeries, isEmpty);
    expect(repository.volumes.single.seriesId, 's1');
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);
    await tester.enterText(nameField(), 'One');
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a name of punctuation only is refused', (tester) async {
    await openSheet(tester);

    await tester.enterText(nameField(), '!!!');
    await tester.enterText(volumesField(), '1-3');
    await tester.pump();

    expect(find.text('Donnez un nom à la série'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
  });

  testWidgets('submitting "!!!" from the keyboard writes nothing', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(nameField(), '!!!');
    await tester.enterText(volumesField(), '1-3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AddSeriesSheet), findsOneWidget);
    expect(repository.createdSeries, isEmpty);
  });
}
