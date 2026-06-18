import 'dart:convert';

import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
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
  );
}

void main() {
  group('fetchBookByIsbn', () {
    test('returns a mapped book on a 200 with results', () async {
      final body = jsonEncode({
        'totalItems': 1,
        'items': [
          {
            'volumeInfo': {
              'title': 'Dune',
              'authors': ['Frank Herbert'],
            },
          },
        ],
      });
      final repository = repositoryReturning((_) => http.Response(body, 200));

      final book = await repository.fetchBookByIsbn('123');

      expect(book, isNotNull);
      expect(book!.title, 'Dune');
      expect(book.isbn, '123');
    });

    test('returns null on a 200 with no results', () async {
      final repository = repositoryReturning(
        (_) => http.Response(jsonEncode({'totalItems': 0}), 200),
      );

      expect(await repository.fetchBookByIsbn('123'), isNull);
    });

    test('throws GoogleBooksQuotaExceededException on a 429', () async {
      final repository = repositoryReturning((_) => http.Response('', 429));

      expect(
        () => repository.fetchBookByIsbn('123'),
        throwsA(isA<GoogleBooksQuotaExceededException>()),
      );
    });

    test('returns null when the request throws', () async {
      final repository = repositoryReturning((_) => throw Exception('network'));

      expect(await repository.fetchBookByIsbn('123'), isNull);
    });

    test('GoogleBooksQuotaExceededException has a readable message', () {
      expect(GoogleBooksQuotaExceededException().toString(), contains('quota'));
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

    test('saveBook stores the book with the uid', () async {
      final book = BookModel(
        id: '',
        uid: '',
        title: 'Dune',
        authors: const ['Frank Herbert'],
        isbn: '123',
        scannedAt: DateTime(2024),
      );

      await repository.saveBook('user-1', book);

      final docs = await firestore.collection('books').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.single.data()['uid'], 'user-1');
      expect(docs.docs.single.data()['title'], 'Dune');
    });

    test('deleteBook removes the document', () async {
      final ref = await firestore.collection('books').add({'title': 'X'});

      await repository.deleteBook(ref.id);

      final doc = await firestore.collection('books').doc(ref.id).get();
      expect(doc.exists, isFalse);
    });
  });
}
