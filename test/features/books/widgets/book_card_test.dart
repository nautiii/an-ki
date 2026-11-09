import 'dart:io';

import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  Volume volume({
    String? imageUrl,
    List<String> authors = const ['Orwell'],
    String title = '1984',
    String? isbn = '123',
  }) => Volume(
    id: '1',
    isbn: isbn,
    title: title,
    authors: authors,
    publishedDate: '1949',
    imageUrl: imageUrl,
    lookup: LookupState.found,
    addedAt: DateTime(2026, 11, 9),
  );

  group('BookCard', () {
    testWidgets('renders a network cover and the metadata', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookCard(volume: volume(imageUrl: 'https://example.com/cover.jpg')),
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

    testWidgets('shows no ISBN line for a volume without ISBN', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(BookCard(volume: volume(isbn: null)));
        await tester.pumpAndSettle();

        expect(find.text('1984'), findsOneWidget);
        expect(find.textContaining('ISBN'), findsNothing);
      });
    });

    testWidgets('falls back to a placeholder cover, without one or when it '
        'cannot load', (tester) async {
      await mockNetworkImages(statusCode: HttpStatus.notFound, () async {
        await tester.pumpHarness(
          Column(
            children: [
              SizedBox(
                height: 180,
                child: BookCard(volume: volume(authors: const [])),
              ),
              SizedBox(
                height: 180,
                child: BookCard(
                  volume: volume(imageUrl: 'https://example.com/lost.jpg'),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.book_rounded), findsNWidgets(2));
      });
    });

    testWidgets('names a book without title', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(BookCard(volume: volume(title: '')));
        await tester.pumpAndSettle();

        expect(find.text('Titre inconnu'), findsOneWidget);
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
              child: BookCard(volume: volume()),
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
