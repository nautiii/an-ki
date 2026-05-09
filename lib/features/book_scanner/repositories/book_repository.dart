import 'dart:convert';

import 'package:an_ki/features/book_scanner/models/book_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

class BookRepository {
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
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
        print('Google Books API: Quota exceeded (429)');
      }
    } catch (e) {
      print('Google Books Error: $e');
    }
    return null;
  }
}
