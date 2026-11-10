import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  group('SeriesCover', () {
    testWidgets('shows the initials without an image', (tester) async {
      await tester.pumpHarness(const SeriesCover(name: 'One Piece'));

      expect(find.text('OP'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an empty image address counts as no image', (tester) async {
      await tester.pumpHarness(
        const SeriesCover(name: 'Blacksad', imageUrl: ''),
      );

      expect(find.text('B'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a name without a letter shows a book', (tester) async {
      await tester.pumpHarness(const SeriesCover(name: '   '));

      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('keeps the initials while the image loads, then shows it', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          const SeriesCover(name: 'One Piece', imageUrl: 'https://img/op.jpg'),
        );

        // Avant la première image : le repli.
        expect(find.text('OP'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
      });
    });

    testWidgets('falls back on the initials when the image fails', (
      tester,
    ) async {
      await mockNetworkImages(statusCode: 404, () async {
        await tester.pumpHarness(
          const SeriesCover(
            name: 'One Piece',
            imageUrl: 'https://img/broken.jpg',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('OP'), findsOneWidget);
      });
    });

    testWidgets('is a 2:3 cover of the asked width', (tester) async {
      await tester.pumpHarness(const SeriesCover(name: 'One Piece', width: 96));

      expect(tester.getSize(find.byType(SeriesCover)), const Size(96, 144));
    });

    testWidgets('is left out of the semantics tree', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const SeriesCover(name: 'One Piece'));

      expect(find.bySemanticsLabel('OP'), findsNothing);
      semantics.dispose();
    });
  });
}
