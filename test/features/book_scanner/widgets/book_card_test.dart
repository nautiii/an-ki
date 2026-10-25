import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  Book book({String? imageUrl, List<String> authors = const ['Orwell']}) =>
      Book(
        id: '1',
        isbn: '123',
        title: '1984',
        authors: authors,
        description: 'Dystopia',
        publishedDate: '1949',
        imageUrl: imageUrl,
      );

  group('BookCard', () {
    testWidgets('renders a network cover and the metadata', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookCard(book: book(imageUrl: 'https://example.com/cover.jpg')),
        );
        await tester.pumpAndSettle();

        expect(find.text('1984'), findsOneWidget);
        expect(find.text('Orwell'), findsOneWidget);
        expect(find.textContaining('ISBN'), findsOneWidget);
        expect(find.textContaining('123'), findsOneWidget);
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

    testWidgets('scrolls rather than overflows at 200 % text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: BookCard(book: book()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('1984'), findsOneWidget);
      });
    });
  });
}
