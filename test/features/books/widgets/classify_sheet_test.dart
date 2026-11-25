import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

Series _series(String id, String name) =>
    Series(id: id, name: name, keys: [name.toLowerCase()], complete: false);

Volume _owned(String id, String seriesId, int number) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  title: '',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

/// Un tome sans titre : AnKi n'a rien à proposer.
final _loose = Volume(
  id: 'v1',
  isbn: '9782344059562',
  title: '',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 9),
);

const _hint =
    'Vous avez déjà ce tome, il comptera comme un deuxième exemplaire.';

void main() {
  late RecordingBookshelfRepository repository;

  Future<void> openSheet(
    WidgetTester tester, {
    Volume? volume,
    List<Volume> others = const [],
    List<Series>? series,
    String? seriesId,
    int? number,
  }) async {
    repository = RecordingBookshelfRepository(
      series:
          series ??
          [
            _series('s1', 'One Piece'),
            _series('s2', 'Astérix'),
            _series('s3', 'Blacksad'),
          ],
      volumes: [volume ?? _loose, ...others],
    );
    await tester.pumpHarness(
      // L'étagère est chargée avant la feuille, comme sur ses écrans.
      Consumer(
        builder: (context, ref, _) {
          ref.watch(shelfProvider);
          return TextButton(
            onPressed: () => ClassifySheet.show(
              context,
              volume ?? _loose,
              seriesId: seriesId,
              number: number,
            ),
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

  Finder field(String label) => find.widgetWithText(TextField, label);
  final search = field('Chercher ou créer une série');
  FilledButton save(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Ranger'));
  String? chosen(WidgetTester tester) => tester
      .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
      .groupValue;

  testWidgets('names the volume and lists the series A to Z', (tester) async {
    await openSheet(tester);

    expect(find.text('Classer ce tome'), findsOneWidget);
    expect(find.text('ISBN 9782344059562'), findsOneWidget);
    final tops = [
      for (final label in ['Astérix', 'Blacksad', 'One Piece'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(find.textContaining('Créer'), findsNothing);
  });

  testWidgets('a series shows its last volume', (tester) async {
    await openSheet(
      tester,
      others: [for (var n = 1; n <= 6; n++) _owned('b$n', 's3', n)],
    );

    expect(find.text('Dernier tome\u00a06'), findsOneWidget);
    expect(find.text('Aucun tome'), findsNWidgets(2));
  });

  testWidgets('searching filters the series', (tester) async {
    await openSheet(tester);

    await tester.enterText(search, 'pie');
    await tester.pump();

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Astérix'), findsNothing);
    expect(find.text('Créer «\u00a0pie\u00a0»'), findsOneWidget);
  });

  testWidgets('a search with no match offers only « Créer »', (tester) async {
    await openSheet(tester);

    await tester.enterText(search, 'Berserk');
    await tester.pump();

    expect(find.byType(RadioListTile<String>), findsOneWidget);
    expect(find.text('Créer « Berserk »'), findsOneWidget);
  });

  testWidgets('blanks or punctuation alone create nothing', (tester) async {
    await openSheet(tester);

    await tester.enterText(search, '   ');
    await tester.pump();
    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    expect(find.textContaining('Créer'), findsNothing);

    await tester.enterText(search, '!!!');
    await tester.pump();
    expect(find.textContaining('Créer'), findsNothing);
  });

  testWidgets('the chosen series stays on top of a search', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Blacksad'));
    await tester.pump();
    await tester.enterText(search, 'pie');
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Blacksad')).dy,
      lessThan(tester.getTopLeft(find.text('One Piece')).dy),
    );
    expect(chosen(tester), 's3');
  });

  testWidgets("a volume's own number stays when the series changes", (
    tester,
  ) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        seriesId: 's3',
        number: 7,
        title: '',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    await tester.tap(find.text('One Piece'));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('the keyboard opening keeps the field focused and its text', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.showKeyboard(search);
    await tester.enterText(search, 'pie');
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(search);
    expect(field.controller!.text, 'pie');
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      same(field),
    );

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Classer ce tome'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      same(tester.widget<TextField>(search)),
    );
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('keyboard open on a small phone at ${scale * 100} % text: '
        'the series still show', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openSheet(tester);
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // L'en-tête laisse sa place, une série reste à portée.
      expect(find.text('Classer ce tome'), findsNothing);
      expect(find.text('Astérix').hitTestable(), findsOneWidget);
    });
  }
  testWidgets('choosing a series fills in its next volume', (tester) async {
    await openSheet(
      tester,
      others: [for (var n = 1; n <= 6; n++) _owned('b$n', 's3', n)],
    );
    expect(save(tester).onPressed, isNull);

    await tester.tap(find.text('Blacksad'));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('a number typed is kept when the series changes', (tester) async {
    await openSheet(
      tester,
      others: [for (var n = 1; n <= 6; n++) _owned('b$n', 's3', n)],
    );

    await tester.tap(find.text('One Piece'));
    await tester.pump();
    await tester.enterText(field('Numéro du tome'), '42');
    await tester.pump();
    await tester.tap(find.text('Blacksad'));
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('a bad number shows its error and keeps "Ranger" disabled', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('One Piece'));
    await tester.pump();
    expect(find.text('Un numéro entre 1 et 1000'), findsNothing);

    await tester.enterText(field('Numéro du tome'), '1001');
    await tester.pump();

    expect(find.text('Un numéro entre 1 et 1000'), findsOneWidget);
    expect(save(tester).onPressed, isNull);
    expect(repository.volumes.single.seriesId, isNull);
  });

  testWidgets('puts the volume in an existing series', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('One Piece'));
    await tester.pump();
    await tester.enterText(field('Numéro du tome'), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    final volume = repository.volumes.single;
    expect((volume.seriesId, volume.number), ('s1', 5));
    expect(find.byType(ClassifySheet), findsNothing);
  });

  testWidgets('creates the series of the name typed', (tester) async {
    await openSheet(tester);

    await tester.enterText(search, 'Berserk');
    await tester.pump();
    await tester.tap(find.text('Créer «\u00a0Berserk\u00a0»'));
    await tester.pump();
    await tester.enterText(field('Numéro du tome'), '3');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    final created = repository.createdSeries.single;
    expect(created.name, 'Berserk');
    final volume = repository.volumes.single;
    expect((volume.seriesId, volume.number), (created.id, 3));
  });

  testWidgets('a name that already exists offers that series, never a '
      'duplicate', (tester) async {
    await openSheet(tester);

    // Même clé que « One Piece », casse et espaces mis à part.
    await tester.enterText(search, '  one piece ');
    await tester.pump();

    expect(find.textContaining('Créer'), findsNothing);
    await tester.tap(find.text('One Piece'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    expect(repository.createdSeries, isEmpty);
    expect(repository.volumes.single.seriesId, 's1');
  });

  testWidgets('« Créer » then a name that exists picks that series', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(search, 'One');
    await tester.pump();
    await tester.tap(find.text('Créer «\u00a0One\u00a0»'));
    await tester.pump();
    await tester.enterText(search, 'One Piece');
    await tester.pump();

    expect(chosen(tester), 's1');
  });

  testWidgets('with no series yet, says how to create one', (tester) async {
    await openSheet(tester, series: const []);

    expect(
      find.text('Aucune série encore : tapez son nom pour la créer.'),
      findsOneWidget,
    );
  });

  testWidgets('opens on the suggestion of « À classer »', (tester) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        title: 'Blacksad tome 7',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    expect(chosen(tester), 's3');
    expect(find.text('7'), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('a suggested new series is a « Créer » row, the list stays '
      'whole', (tester) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        title: 'Berserk tome 3',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    expect(find.text('Créer «\u00a0Berserk\u00a0»'), findsOneWidget);
    expect(find.text('Astérix'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    expect(repository.createdSeries.single.name, 'Berserk');
    expect(repository.volumes.single.number, 3);
  });

  testWidgets('a volume whose series is gone starts with none', (tester) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        seriesId: 'gone',
        number: 7,
        title: '',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    expect(chosen(tester), isNull);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('says when the number is already owned', (tester) async {
    // Un tome 7 de Blacksad est déjà là.
    await openSheet(tester, others: [_owned('b7', 's3', 7)]);
    await tester.tap(find.text('Blacksad'));
    await tester.pump();
    expect(find.text(_hint), findsNothing);

    await tester.enterText(field('Numéro du tome'), '7');
    await tester.pump();
    expect(find.text(_hint), findsOneWidget);
    // Permis : un deuxième exemplaire reste un choix.
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();
    expect(
      [for (final v in repository.volumes) (v.seriesId, v.number)],
      [('s3', 7), ('s3', 7)],
    );
  });

  testWidgets('a scanned volume replaces one added by hand, no hint', (
    tester,
  ) async {
    await openSheet(
      tester,
      volume: Volume(
        id: '9782344059562',
        isbn: '9782344059562',
        title: 'Blacksad 7',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
      others: [_owned('by-hand', 's3', 7)],
    );
    await tester.tap(find.text('Blacksad'));
    await tester.pump();
    await tester.enterText(field('Numéro du tome'), '7');
    await tester.pump();
    expect(find.text(_hint), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();
    expect(
      [for (final v in repository.volumes) (v.id, v.seriesId, v.number)],
      [('9782344059562', 's3', 7)],
    );
  });

  testWidgets('starts on a given series and number', (tester) async {
    await openSheet(tester, seriesId: 's2', number: 3);

    expect(find.text('3'), findsOneWidget);
    expect(chosen(tester), 's2');
  });

  testWidgets('starts on the current series and number', (tester) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        seriesId: 's3',
        number: 7,
        title: 'T7',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(chosen(tester), 's3');
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    await openSheet(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('holds at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openSheet(tester);

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Ranger'), findsOneWidget);
  });
}
