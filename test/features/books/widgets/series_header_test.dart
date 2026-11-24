import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/series_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

ShelfEntry _entry(List<int> numbers, {String? imageUrl}) => shelfOf(
  [
    Series(
      id: 's1',
      name: 'Blacksad',
      keys: const ['blacksad'],
      complete: false,
      artwork: imageUrl == null
          ? null
          : SeriesArtwork(
              url: imageUrl,
              forName: 'Blacksad',
              checkedAt: DateTime(2026),
            ),
    ),
  ],
  [
    for (final n in numbers)
      Volume(
        id: 'v$n',
        seriesId: 's1',
        number: n,
        title: 'Tome $n',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
  ],
).entries.single;

void main() {
  testWidgets('name, last volume and how many are owned', (tester) async {
    await tester.pumpHarness(
      SingleChildScrollView(
        child: SeriesHeader(entry: _entry([1, 2, 4]), topInset: 0),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('dernier tome'), findsOneWidget);
    expect(find.text('3 tomes sur 4'), findsOneWidget);
    // Sans image : la jaquette porte le nom, en plus du titre.
    expect(find.text('Blacksad'), findsNWidgets(2));
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('reads as one header', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      SingleChildScrollView(
        child: SeriesHeader(entry: _entry([1, 2, 4]), topInset: 0),
      ),
    );

    final header = find.bySemanticsLabel(
      'Blacksad, 3 tomes sur 4, dernier tome 4',
    );
    expect(header, findsOneWidget);
    expect(tester.getSemantics(header).flagsCollection.isHeader, isTrue);
    // Les textes visibles ne sont pas lus à part.
    expect(find.bySemanticsLabel('dernier tome'), findsNothing);
    semantics.dispose();
  });

  testWidgets('an empty series has no big number', (tester) async {
    await tester.pumpHarness(
      SingleChildScrollView(
        child: SeriesHeader(entry: _entry(const []), topInset: 0),
      ),
    );

    expect(find.text('dernier tome'), findsNothing);
  });

  testWidgets('with an image, it blurs it behind the header', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        SingleChildScrollView(
          child: SeriesHeader(
            entry: _entry([1], imageUrl: 'https://img/blacksad.jpg'),
            topInset: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}
