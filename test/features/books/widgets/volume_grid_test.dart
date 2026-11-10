import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/volume_grid.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _series = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);

Volume _volume(int number) => Volume(
  id: 'v$number',
  seriesId: 's1',
  number: number,
  isbn: 'isbn$number',
  title: 'Tome $number',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

/// Tomes possédés [owned] de One Piece.
ShelfEntry _entry(List<int> owned) => shelfOf(
  const [_series],
  [for (final n in owned) _volume(n)],
).entries.single;

void main() {
  Future<void> pumpGrid(
    WidgetTester tester,
    ShelfEntry entry, {
    RecordingBookshelfRepository? repository,
  }) => tester.pumpHarness(
    CustomScrollView(slivers: [VolumeGrid(entry: entry)]),
    overrides: [
      bookshelfRepositoryProvider.overrideWithValue(
        repository ??
            RecordingBookshelfRepository(
              series: const [_series],
              volumes: entry.volumes,
            ),
      ),
      currentUidProvider.overrideWithValue('fake-uid'),
    ],
  );

  testWidgets('draws every number from 1 to the last owned one', (
    tester,
  ) async {
    await pumpGrid(tester, _entry([1, 2, 5]));

    for (var n = 1; n <= 5; n++) {
      expect(find.text('$n'), findsOneWidget);
    }
    expect(find.text('6'), findsNothing);
  });

  testWidgets('says owned and missing numbers to TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGrid(tester, _entry([1, 2, 5]));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Tome 1, possédé')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    // Un tome manquant n'est pas un bouton : rien à ouvrir.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tome 3, manquant')),
      isSemantics(isButton: false, hasTapAction: false),
    );
    expect(find.bySemanticsLabel('Tome 4, manquant'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('touching an owned number opens its sheet', (tester) async {
    await pumpGrid(tester, _entry([1, 2, 5]));

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsOneWidget);
    expect(find.text('Tome 2'), findsWidgets);
  });

  testWidgets('touching a missing number does nothing', (tester) async {
    await pumpGrid(tester, _entry([1, 5]));

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsNothing);
  });

  testWidgets('never draws a cell narrower than 48 dp', (tester) async {
    final owned = [for (var n = 1; n <= 40; n++) n];
    final entry = _entry(owned);
    await tester.pumpHarness(
      Center(
        child: SizedBox(
          width: 327,
          child: CustomScrollView(slivers: [VolumeGrid(entry: entry)]),
        ),
      ),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(
          RecordingBookshelfRepository(
            series: const [_series],
            volumes: entry.volumes,
          ),
        ),
        currentUidProvider.overrideWithValue('fake-uid'),
      ],
    );

    final cells = find.byType(InkWell).evaluate().length;
    expect(cells, greaterThan(0));
    for (var i = 0; i < cells; i++) {
      expect(
        tester.getSize(find.byType(InkWell).at(i)).width,
        greaterThanOrEqualTo(48),
      );
    }
  });

  group('several editions of one number', () {
    ShelfEntry twoEditions() {
      Volume edition(String id, String title, String isbn) => Volume(
        id: id,
        seriesId: 's1',
        number: 3,
        isbn: isbn,
        title: title,
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      );
      return shelfOf(
        const [_series],
        [
          _volume(1),
          edition('ea', 'Édition A', '9782344059562'),
          edition('eb', 'Édition B', '9782723488525'),
        ],
      ).entries.single;
    }

    testWidgets('says it to TalkBack and shows a badge', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpGrid(tester, twoEditions());

      expect(
        find.bySemanticsLabel('Tome 3, possédé en 2 éditions'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Tome 1, possédé'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('asks which edition, then opens the chosen one', (
      tester,
    ) async {
      await pumpGrid(tester, twoEditions());

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(find.text('Tome 3\u00a0: quelle édition\u00a0?'), findsOneWidget);
      expect(find.text('Édition A'), findsOneWidget);
      expect(find.text('ISBN 9782344059562'), findsOneWidget);
      expect(find.text('Édition B'), findsOneWidget);
      expect(find.text('ISBN 9782723488525'), findsOneWidget);
      expect(find.byType(VolumeSheet), findsNothing);

      await tester.tap(find.text('Édition B'));
      await tester.pumpAndSettle();

      expect(find.byType(VolumeSheet), findsOneWidget);
      expect(find.text('ISBN 9782723488525'), findsOneWidget);
      expect(find.text('Quelle édition'), findsNothing);
    });
  });

  testWidgets('has fewer, bigger columns at 200 % text', (tester) async {
    final owned = [for (var n = 1; n <= 40; n++) n];
    await pumpGrid(tester, _entry(owned));
    final normal = _columns(tester);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final large = _columns(tester);

    expect(large, lessThan(normal));
    expect(tester.takeException(), isNull);
  });
}

/// Nombre de cases sur la première ligne de la grille.
int _columns(WidgetTester tester) {
  final top = tester.getTopLeft(find.text('1')).dy;
  return [
    for (var n = 1; n <= 40; n++)
      if (find.text('$n').evaluate().isNotEmpty &&
          (tester.getTopLeft(find.text('$n')).dy - top).abs() < 20)
        n,
  ].length;
}
