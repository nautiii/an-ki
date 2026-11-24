import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/release_date_sheet.dart';
import 'package:an_ki/features/books/widgets/spine_shelf.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 24);

Volume _volume(int number, {String? id}) => Volume(
  id: id ?? 'v$number',
  seriesId: 's1',
  number: number,
  isbn: id,
  title: 'Tome $number',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

ShelfEntry _entry(List<Volume> volumes, {NextVolumeInfo? next}) => shelfOf([
  Series(
    id: 's1',
    name: 'One Piece',
    keys: const ['one piece'],
    complete: false,
    next: next,
  ),
], volumes).entries.single;

void main() {
  final key = GlobalKey<SpineShelfState>();

  Future<List<int>> pumpShelf(WidgetTester tester, ShelfEntry entry) async {
    final added = <int>[];
    await tester.pumpHarness(
      SpineShelf(key: key, entry: entry, today: _today, onAdd: added.add),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(
          RecordingBookshelfRepository(volumes: entry.volumes),
        ),
        currentUidProvider.overrideWithValue('fake-uid'),
        todayProvider.overrideWithValue(_today),
      ],
    );
    // Le rayon se place sur les derniers tomes après sa première image.
    await tester.pump();
    return added;
  }

  testWidgets('one spine per volume, missing ones marked, the next one', (
    tester,
  ) async {
    await pumpShelf(
      tester,
      _entry(
        [_volume(1), _volume(3)],
        next: NextVolumeInfo(
          number: 4,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.bnf,
          checkedAt: DateTime(2026, 11),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Tome 1, possédé'), findsOneWidget);
    expect(find.bySemanticsLabel('Tome 2, manquant'), findsOneWidget);
    expect(find.bySemanticsLabel('Tome 3, possédé'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tome 4 · sortie le 3 décembre'),
      findsOneWidget,
    );
  });

  testWidgets('a missing spine adds it, an owned one opens it', (tester) async {
    final added = await pumpShelf(tester, _entry([_volume(1), _volume(3)]));

    await tester.tap(find.bySemanticsLabel('Tome 2, manquant'));
    expect(added, [2]);

    await tester.tap(find.bySemanticsLabel('Tome 3, possédé'));
    await tester.pumpAndSettle();
    expect(find.byType(VolumeSheet), findsOneWidget);
  });

  testWidgets('the announced spine opens the release date sheet', (
    tester,
  ) async {
    await pumpShelf(
      tester,
      _entry(
        [_volume(1)],
        next: NextVolumeInfo(
          number: 2,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.bnf,
          checkedAt: DateTime(2026, 11),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Tome 2 · sortie le 3 décembre'));
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseDateSheet), findsOneWidget);
  });

  testWidgets('two editions of a number: pick one first', (tester) async {
    await pumpShelf(
      tester,
      _entry([
        _volume(1, id: '9782723488525'),
        _volume(1, id: '9782344059562'),
      ]),
    );

    expect(
      find.bySemanticsLabel('Tome 1, possédé en 2 éditions'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Tome 1, possédé en 2 éditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ISBN 9782344059562'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsOneWidget);
  });

  testWidgets('opens on the last volumes, then shows any number', (
    tester,
  ) async {
    await pumpShelf(tester, _entry([for (var n = 1; n <= 60; n++) _volume(n)]));

    expect(find.bySemanticsLabel('Tome 60, possédé'), findsOneWidget);
    expect(find.bySemanticsLabel('Tome 1, possédé'), findsNothing);

    key.currentState!.show(2);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tome 2, possédé'), findsOneWidget);
    expect(find.bySemanticsLabel('Tome 60, possédé'), findsNothing);
  });

  testWidgets('a released next volume is a spine to mark bought', (
    tester,
  ) async {
    final added = await pumpShelf(
      tester,
      _entry(
        [_volume(1)],
        next: NextVolumeInfo(
          number: 2,
          status: ReleaseStatus.released,
          source: ReleaseSource.bnf,
          checkedAt: DateTime(2026, 11),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Tome 2, manquant'));

    expect(added, [2]);
  });

  testWidgets('a closed series shows no next spine', (tester) async {
    final entry = shelfOf(
      [
        const Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: true,
        ),
      ],
      [_volume(1)],
    ).entries.single;
    await pumpShelf(tester, entry);

    expect(find.bySemanticsLabel('Tome 1, possédé'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tome 2')), findsNothing);
  });

  testWidgets('show() of a number off the shelf does nothing', (tester) async {
    await pumpShelf(tester, _entry([for (var n = 1; n <= 60; n++) _volume(n)]));

    key.currentState!.show(999);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tome 60, possédé'), findsOneWidget);
  });

  testWidgets('every spine is a large labelled target', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShelf(tester, _entry([_volume(1), _volume(3)]));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
