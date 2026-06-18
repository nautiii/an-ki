import 'dart:convert';

import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  BookRepository({FirebaseFirestore? firestore, http.Client? httpClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _httpClient = httpClient ?? http.Client();

  static const _apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  CollectionReference<Map<String, dynamic>> get _books =>
      _firestore.collection('books');

  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$_apiKey',
    );
    try {
      final response = await _httpClient.get(url);
      debugPrint('Google Books Response: ${response.body}');
      debugPrint('Google Books Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final totalItems = data['totalItems'] as int?;
        if (totalItems != null && totalItems > 0) {
          final items = data['items'] as List<dynamic>;
          final item = items.first as Map<String, dynamic>;
          return BookModel.fromJson(item, isbn);
        }
      } else if (response.statusCode == 429) {
        throw GoogleBooksQuotaExceededException();
      }
    } on GoogleBooksQuotaExceededException {
      // Propagate so the UI can show the dedicated "quota exceeded" message.
      rethrow;
    } catch (e) {
      debugPrint('Google Books Error: $e');
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
