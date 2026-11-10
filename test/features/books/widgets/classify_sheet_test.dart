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

final _loose = Volume(
  id: 'v1',
  title: 'Romance Dawn',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 9),
);

void main() {
  late RecordingBookshelfRepository repository;

  Future<void> openSheet(WidgetTester tester, {Volume? volume}) async {
    repository = RecordingBookshelfRepository(
      series: [
        _series('s1', 'One Piece'),
        _series('s2', 'Astérix'),
        _series('s3', 'Blacksad'),
      ],
      volumes: [volume ?? _loose],
    );
    await tester.pumpHarness(
      // L'étagère est chargée avant la feuille, comme sur ses écrans.
      Consumer(
        builder: (context, ref, _) {
          ref.watch(shelfProvider);
          return TextButton(
            onPressed: () => ClassifySheet.show(context, volume ?? _loose),
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

  testWidgets('lists the series A to Z, then "Nouvelle série"', (tester) async {
    await openSheet(tester);

    final tops = [
      for (final label in [
        'Astérix',
        'Blacksad',
        'One Piece',
        'Nouvelle série',
      ])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(find.text('Classer ce tome'), findsOneWidget);
  });

  testWidgets('"Ranger" is disabled until a series and a number are given', (
    tester,
  ) async {
    await openSheet(tester);

    FilledButton button() =>
        tester.widget(find.widgetWithText(FilledButton, 'Ranger'));
    expect(button().onPressed, isNull);

    await tester.tap(find.text('One Piece'));
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(field('Numéro du tome'), '5');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('a bad number shows its error and keeps "Ranger" disabled', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('One Piece'));
    await tester.pump();
    // Rien de saisi : pas encore d'erreur.
    expect(find.text('Un numéro entre 1 et 1000'), findsNothing);

    await tester.enterText(field('Numéro du tome'), '1001');
    await tester.pump();

    expect(find.text('Un numéro entre 1 et 1000'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ranger'),
    );
    expect(button.onPressed, isNull);
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

  testWidgets('a new series is created, then the volume classified in it', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Nouvelle série'));
    await tester.pump();
    await tester.enterText(field('Nom de la série'), 'Berserk');
    await tester.enterText(field('Numéro du tome'), '3');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    final created = repository.createdSeries.single;
    expect(created.name, 'Berserk');
    final volume = repository.volumes.single;
    expect((volume.seriesId, volume.number), (created.id, 3));
  });

  testWidgets('a "new" series that already exists gets the volume, '
      'without a duplicate', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Nouvelle série'));
    await tester.pump();
    // Même clé que « One Piece », casse et espaces mis à part.
    await tester.enterText(field('Nom de la série'), '  one piece ');
    await tester.enterText(field('Numéro du tome'), '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ranger'));
    await tester.pumpAndSettle();

    expect(repository.createdSeries, isEmpty);
    final volume = repository.volumes.single;
    expect((volume.seriesId, volume.number), ('s1', 4));
  });

  testWidgets('a new series needs a name', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Nouvelle série'));
    await tester.pump();
    await tester.enterText(field('Numéro du tome'), '3');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ranger'),
    );
    expect(button.onPressed, isNull);

    // Un nom effacé après saisie : l'erreur s'affiche sous le champ.
    await tester.enterText(field('Nom de la série'), 'B');
    await tester.pump();
    await tester.enterText(field('Nom de la série'), '');
    await tester.pump();

    expect(find.text('Donnez un nom à la série'), findsOneWidget);
    expect(repository.createdSeries, isEmpty);
    expect(find.byType(ClassifySheet), findsOneWidget);
  });

  testWidgets('a volume whose series is gone starts with none', (tester) async {
    await openSheet(
      tester,
      volume: Volume(
        id: 'v1',
        seriesId: 'gone',
        number: 7,
        title: 'T7',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ranger'),
    );
    expect(button.onPressed, isNull);
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
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ranger'),
    );
    expect(button.onPressed, isNotNull);
  });
}
