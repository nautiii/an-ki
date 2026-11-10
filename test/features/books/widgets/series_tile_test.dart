import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/series_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 8);

/// One Piece : tomes 1 à 108 sauf 13 et 14, tome 109 annoncé le 3 décembre.
ShelfEntry _onePiece() => shelfOf(
  [
    Series(
      id: 'op',
      name: 'One Piece',
      keys: const ['one piece'],
      complete: false,
      next: NextVolumeInfo(
        number: 109,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12, day: 3),
        source: ReleaseSource.bnf,
        checkedAt: DateTime(2026, 11, 8),
      ),
    ),
  ],
  [
    for (var n = 1; n <= 108; n++)
      if (n != 13 && n != 14)
        Volume(
          id: '$n',
          seriesId: 'op',
          number: n,
          title: 'T$n',
          authors: const [],
          lookup: LookupState.found,
          addedAt: DateTime(2026),
        ),
  ],
).entries.single;

void main() {
  final overrides = [todayProvider.overrideWithValue(_today)];

  Future<void> pumpTile(
    WidgetTester tester, {
    ShelfEntry? entry,
    VoidCallback? onTap,
  }) => tester.pumpHarness(
    Padding(
      padding: const EdgeInsets.all(16),
      child: SeriesTile(entry: entry ?? _onePiece(), onTap: onTap ?? () {}),
    ),
    overrides: overrides,
  );

  testWidgets('shows the name, the last volume, the next and the holes', (
    tester,
  ) async {
    await pumpTile(tester);

    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('108'), findsOneWidget);
    expect(find.text('Prochain : tome 109 · 3 décembre'), findsOneWidget);
    expect(find.text('Il vous manque 13, 14'), findsOneWidget);
  });

  testWidgets('an empty series has no big number', (tester) async {
    final empty = shelfOf(const [
      Series(id: 's', name: 'Naruto', keys: [], complete: false),
    ], const []).entries.single;
    await pumpTile(tester, entry: empty);

    expect(find.byType(LastVolumeNumber), findsNothing);
    expect(find.text('Il vous manque 1'), findsNothing);
  });

  testWidgets('reads as one single label for TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(tester);

    expect(
      find.bySemanticsLabel(
        'One Piece, dernier tome 108, prochain tome 109, sortie le 3 décembre, '
        'il vous manque les tomes 13 et 14',
      ),
      findsOneWidget,
    );
    // Les textes visibles ne sont pas lus à part.
    expect(find.bySemanticsLabel('One Piece'), findsNothing);
    expect(find.bySemanticsLabel('108'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a tap calls onTap', (tester) async {
    var taps = 0;
    await pumpTile(tester, onTap: () => taps++);

    await tester.tap(find.byType(SeriesTile));

    expect(taps, 1);
  });

  testWidgets('stacks the cover above the text at 200 % without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTile(tester);

    expect(tester.takeException(), isNull);
    final cover = tester.getRect(find.byType(SeriesCover));
    final name = tester.getRect(find.text('One Piece'));
    expect(name.top, greaterThanOrEqualTo(cover.bottom));
    // Le texte garde toute la largeur de la ligne.
    expect(name.left, cover.left);
  });

  testWidgets('keeps the cover beside the text at normal size', (tester) async {
    await pumpTile(tester);

    final cover = tester.getRect(find.byType(SeriesCover));
    final name = tester.getRect(find.text('One Piece'));
    expect(name.left, greaterThanOrEqualTo(cover.right));
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
