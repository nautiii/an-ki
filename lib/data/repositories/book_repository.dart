import 'dart:convert';

import 'package:an_ki/data/models/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

class GoogleBooksQuotaExceededException implements Exception {
  @override
  String toString() => 'Google Books API quota exceeded.';
}

class BookRepository {
  static const _apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _books =>
      _firestore.collection('books');

  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$_apiKey',
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['totalItems'] != null && data['totalItems'] > 0) {
          final item = data['items'][0];
          return BookModel.fromJson(item, isbn);
        }
      } else if (response.statusCode == 429) {
        throw GoogleBooksQuotaExceededException();
      }
    } catch (e) {
      print('Google Books Error: $e');
    }
    return null;
  }

  Stream<List<BookModel>> watchBooks(String uid) {
    return _books
        .where('uid', isEqualTo: uid)
        .orderBy('scannedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BookModel.fromFirestore).toList());
  }

  Future<void> saveBook(String uid, BookModel book) async {
    await _books.add(book.copyWith(uid: uid).toJson());
  }

  Future<void> deleteBook(String bookId) async {
    await _books.doc(bookId).delete();
  }
}
