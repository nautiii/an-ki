import 'dart:convert';

import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

BookRepository repositoryReturning(
  http.Response Function(http.Request request) handler, {
  FirebaseFirestore? firestore,
}) {
  return BookRepository(
    firestore: firestore ?? FakeFirebaseFirestore(),
    httpClient: MockClient((request) async => handler(request)),
    apiKey: 'test-key',
  );
}

void main() {
  group('fetchBookByIsbn', () {
    test('maps a complete volume and upgrades the cover to https', () async {
      final body = jsonEncode({
        'totalItems': 1,
        'items': [
          {
            'volumeInfo': {
              'title': '1984',
              'authors': ['George Orwell'],
              'imageLinks': {'thumbnail': 'http://books.google.com/cover.jpg'},
              'publishedDate': '1949',
              'description': 'Dystopia',
              'pageCount': 328,
            },
          },
        ],
      });
      final repository = repositoryReturning((_) => http.Response(body, 200));

      final book = await repository.fetchBookByIsbn('9780451524935');

      expect(
        book,
        const Book(
          id: '',
          title: '1984',
          authors: ['George Orwell'],
          isbn: '9780451524935',
          imageUrl: 'https://books.google.com/cover.jpg',
          publishedDate: '1949',
          description: 'Dystopia',
          pageCount: 328,
        ),
      );
    });

    test('falls back to defaults when volumeInfo is missing', () async {
      final body = jsonEncode({
        'totalItems': 1,
        'items': [<String, dynamic>{}],
      });
      final repository = repositoryReturning((_) => http.Response(body, 200));

      final book = await repository.fetchBookByIsbn('123');

      expect(
        book,
        const Book(id: '', title: 'Unknown Title', authors: [], isbn: '123'),
      );
    });

    test('returns null on a 200 with no results', () async {
      final repository = repositoryReturning(
        (_) => http.Response(jsonEncode({'totalItems': 0}), 200),
      );

      expect(await repository.fetchBookByIsbn('123'), isNull);
    });

    test('throws BookFailure.quotaExceeded on a 429', () async {
      final repository = repositoryReturning((_) => http.Response('', 429));

      expect(
        () => repository.fetchBookByIsbn('123'),
        throwsA(BookFailure.quotaExceeded),
      );
    });

    test('returns null when the request throws', () async {
      final repository = repositoryReturning((_) => throw Exception('network'));

      expect(await repository.fetchBookByIsbn('123'), isNull);
    });
  });

  group('Firestore operations', () {
    late FakeFirebaseFirestore firestore;
    late BookRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = repositoryReturning(
        (_) => http.Response('', 200),
        firestore: firestore,
      );
    });

    test(
      'watchBooks returns the user books ordered by scannedAt desc',
      () async {
        await firestore.collection('books').add({
          'uid': 'user-1',
          'title': 'Older',
          'authors': <String>[],
          'isbn': '1',
          'scannedAt': Timestamp.fromDate(DateTime(2023)),
        });
        await firestore.collection('books').add({
          'uid': 'user-1',
          'title': 'Newer',
          'authors': <String>[],
          'isbn': '2',
          'scannedAt': Timestamp.fromDate(DateTime(2024)),
        });

        final books = await repository.watchBooks('user-1').first;

        expect(books.map((b) => b.title), ['Newer', 'Older']);
      },
    );

    test('watchBooks maps every field of a complete document', () async {
      final ref = await firestore.collection('books').add({
        'uid': 'user-1',
        'title': 'Dune',
        'authors': ['Frank Herbert'],
        'isbn': '9780441013593',
        'imageUrl': 'https://x/y.jpg',
        'publishedDate': '1965',
        'description': 'Spice',
        'pageCount': 412,
        'scannedAt': Timestamp.fromDate(DateTime(2024)),
      });

      final books = await repository.watchBooks('user-1').first;

      expect(books, [
        Book(
          id: ref.id,
          title: 'Dune',
          authors: const ['Frank Herbert'],
          isbn: '9780441013593',
          imageUrl: 'https://x/y.jpg',
          publishedDate: '1965',
          description: 'Spice',
          pageCount: 412,
          scannedAt: DateTime(2024),
        ),
      ]);
    });

    test('watchBooks reads an old document missing fields', () async {
      await firestore.collection('books').add({
        'uid': 'user-1',
        'scannedAt': Timestamp.fromDate(DateTime(2024)),
      });

      final book = (await repository.watchBooks('user-1').first).single;

      expect(book.title, '');
      expect(book.authors, isEmpty);
      expect(book.isbn, '');
      expect(book.imageUrl, isNull);
      expect(book.pageCount, isNull);
    });

    test('saveBook stores the book with its owner and date', () async {
      const book = Book(
        id: '',
        title: 'Dune',
        authors: ['Frank Herbert'],
        isbn: '123',
      );

      await repository.saveBook('user-1', book, scannedAt: DateTime(2024));

      final docs = await firestore.collection('books').get();
      expect(docs.docs.single.data(), {
        'uid': 'user-1',
        'title': 'Dune',
        'authors': ['Frank Herbert'],
        'isbn': '123',
        'scannedAt': Timestamp.fromDate(DateTime(2024)),
      });
    });

    test('deleteAllUserBooks removes the books of the uid only', () async {
      for (var i = 0; i < 3; i++) {
        await firestore.collection('books').add({
          'uid': 'user-1',
          'title': '$i',
        });
      }
      await firestore.collection('books').add({
        'uid': 'user-2',
        'title': 'Keep',
      });

      await repository.deleteAllUserBooks('user-1');

      final remaining = (await firestore.collection('books').get()).docs;
      expect(remaining.map((d) => d.data()['title']), ['Keep']);
    });
  });
}
