import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  group('BookModel.fromJson (Google Books)', () {
    test('maps a complete volume and upgrades the thumbnail to https', () {
      final book = BookModel.fromJson({
        'volumeInfo': {
          'title': '1984',
          'authors': ['George Orwell'],
          'imageLinks': {'thumbnail': 'http://books.google.com/cover.jpg'},
          'publishedDate': '1949',
          'description': 'Dystopia',
          'pageCount': 328,
        },
      }, '9780451524935');

      expect(book.id, '');
      expect(book.uid, '');
      expect(book.title, '1984');
      expect(book.authors, ['George Orwell']);
      expect(book.isbn, '9780451524935');
      expect(book.imageUrl, 'https://books.google.com/cover.jpg');
      expect(book.publishedDate, '1949');
      expect(book.description, 'Dystopia');
      expect(book.pageCount, 328);
      expect(book.scannedAt, isNotNull);
    });

    test('falls back to defaults when volumeInfo is missing', () {
      final book = BookModel.fromJson(<String, dynamic>{}, '123');

      expect(book.title, 'Unknown Title');
      expect(book.authors, isEmpty);
      expect(book.isbn, '123');
      expect(book.imageUrl, isNull);
      expect(book.publishedDate, isNull);
      expect(book.pageCount, isNull);
    });
  });

  group('BookModel.fromFirestore', () {
    test('maps a complete document', () async {
      await firestore.collection('books').add({
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
      final doc = (await firestore.collection('books').get()).docs.first;

      final book = BookModel.fromFirestore(doc);

      expect(book.id, doc.id);
      expect(book.uid, 'user-1');
      expect(book.title, 'Dune');
      expect(book.authors, ['Frank Herbert']);
      expect(book.scannedAt, DateTime(2024));
    });

    test('handles missing optional fields', () async {
      await firestore.collection('books').add({'title': 'Bare'});
      final doc = (await firestore.collection('books').get()).docs.first;

      final book = BookModel.fromFirestore(doc);

      expect(book.title, 'Bare');
      expect(book.uid, '');
      expect(book.authors, isEmpty);
      expect(book.scannedAt, isNull);
    });
  });

  group('BookModel.toJson', () {
    test('serializes scannedAt as a Timestamp when present', () {
      final book = BookModel(
        id: '1',
        uid: 'u',
        title: 'T',
        authors: const ['A'],
        isbn: '1',
        scannedAt: DateTime(2024),
      );

      expect(book.toJson()['scannedAt'], Timestamp.fromDate(DateTime(2024)));
    });

    test('uses a server timestamp when scannedAt is null', () {
      final book = BookModel(
        id: '1',
        uid: 'u',
        title: 'T',
        authors: const [],
        isbn: '1',
      );

      expect(book.toJson()['scannedAt'], isA<FieldValue>());
    });
  });

  test('copyWith overrides selected fields', () {
    final base = BookModel(
      id: '1',
      uid: 'u',
      title: 'T',
      authors: const ['A'],
      isbn: '1',
    );

    final copy = base.copyWith(uid: 'u2', title: 'T2');

    expect(copy.uid, 'u2');
    expect(copy.title, 'T2');
    expect(copy.id, '1');
    expect(copy.authors, const ['A']);
    expect(base.copyWith().isbn, '1');
  });
}
