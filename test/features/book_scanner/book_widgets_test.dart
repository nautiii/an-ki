import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/widgets/book_card.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

void main() {
  BookModel book({String? imageUrl, List<String> authors = const ['Orwell']}) =>
      BookModel(
        id: '1',
        uid: 'u',
        isbn: '123',
        title: '1984',
        authors: authors,
        description: 'Dystopia',
        publishedDate: '1949',
        imageUrl: imageUrl,
      );

  group('BookInfoSheet', () {
    testWidgets('renders details with a cover image and saves', (tester) async {
      var closed = false;
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(
            book: book(imageUrl: 'https://example.com/cover.jpg'),
            onClosed: () => closed = true,
          ),
          overrides: [
            bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('1984'), findsOneWidget);
        expect(find.text('Orwell'), findsOneWidget);
        expect(find.text('1949'), findsOneWidget);
        expect(find.text('ISBN: 123'), findsOneWidget);

        await tester.tap(find.text('Ajouter'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(closed, isTrue);
      });
    });

    testWidgets('renders a placeholder icon without authors or image', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(
            book: book(authors: const []),
            onClosed: () {},
          ),
          overrides: [
            bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.book_rounded), findsOneWidget);
        expect(find.text('Orwell'), findsNothing);
      });
    });
  });

  group('BookCard', () {
    testWidgets('renders a network cover and the metadata', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookCard(book: book(imageUrl: 'https://example.com/cover.jpg')),
        );
        await tester.pumpAndSettle();

        expect(find.text('1984'), findsOneWidget);
        expect(find.text('Orwell'), findsOneWidget);
        expect(find.text('1949'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });
    });

    testWidgets('falls back to a placeholder cover', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(BookCard(book: book(authors: const [])));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.book_rounded), findsOneWidget);
      });
    });
  });
}
