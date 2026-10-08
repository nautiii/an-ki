import 'dart:convert';

import 'package:an_ki/core/config/app_config.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:an_ki/features/book_scanner/domain/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(
    firestore: ref.watch(firestoreProvider),
    httpClient: ref.watch(httpClientProvider),
    apiKey: ref.watch(appConfigProvider).googleBooksApiKey,
  ),
);

/// Livres : recherche par ISBN sur Google Books, liste de l'utilisateur dans
/// la collection Firestore `books` (documents portant leur `uid`).
///
/// Convertit documents et réponses ↔ [BookModel]. Ni logique métier, ni texte
/// d'UI, ni état.
class BookRepository {
  BookRepository({
    required this._firestore,
    required this._httpClient,
    required this._apiKey,
  });

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  /// Clé Google Books, lue depuis `--dart-define` par [AppConfig].
  final String _apiKey;

  CollectionReference<Map<String, dynamic>> get _books =>
      _firestore.collection('books');

  /// Livre de Google Books pour [isbn] ; null s'il est inconnu ou si la
  /// recherche échoue. Lève [BookFailure.quotaExceeded] quand le quota de
  /// l'API est dépassé.
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$_apiKey',
    );
    try {
      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final totalItems = data['totalItems'] as int?;
        if (totalItems != null && totalItems > 0) {
          final items = data['items'] as List<dynamic>;
          final item = items.first as Map<String, dynamic>;
          return _bookFromVolume(item, isbn);
        }
      } else if (response.statusCode == 429) {
        throw BookFailure.quotaExceeded;
      }
    } on BookFailure {
      // On propage pour que l'UI puisse afficher le message dédié « quota dépassé ».
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
        .map((snapshot) => snapshot.docs.map(_bookFromDoc).toList());
  }

  /// Ajoute [book] à la liste de [uid], daté de [scannedAt] (horloge de
  /// l'app : la liste est triée sur ce champ).
  Future<void> saveBook(
    String uid,
    BookModel book, {
    required DateTime scannedAt,
  }) async {
    await _books.add(_bookToMap(book, uid: uid, scannedAt: scannedAt));
  }

  Future<void> deleteBook(String bookId) async {
    await _books.doc(bookId).delete();
  }
}

// Conversions vers le domaine : privées au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
BookModel _bookFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return BookModel(
    id: doc.id,
    title: data['title'] as String? ?? '',
    authors: List<String>.from(data['authors'] as List<dynamic>? ?? const []),
    isbn: data['isbn'] as String? ?? '',
    imageUrl: data['imageUrl'] as String?,
    publishedDate: data['publishedDate'] as String?,
    description: data['description'] as String?,
    pageCount: data['pageCount'] as int?,
    scannedAt: (data['scannedAt'] as Timestamp?)?.toDate(),
  );
}

Map<String, Object> _bookToMap(
  BookModel book, {
  required String uid,
  required DateTime scannedAt,
}) => {
  'uid': uid,
  'title': book.title,
  'authors': book.authors,
  'isbn': book.isbn,
  'imageUrl': ?book.imageUrl,
  'publishedDate': ?book.publishedDate,
  'description': ?book.description,
  'pageCount': ?book.pageCount,
  'scannedAt': Timestamp.fromDate(scannedAt),
};

/// Volume Google Books (`items[n]`) → livre pas encore ajouté à la liste.
BookModel _bookFromVolume(Map<String, dynamic> item, String isbn) {
  final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
  final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;

  return BookModel(
    id: '',
    title: volumeInfo?['title'] as String? ?? 'Unknown Title',
    authors: List<String>.from(
      volumeInfo?['authors'] as List<dynamic>? ?? const [],
    ),
    isbn: isbn,
    imageUrl: (imageLinks?['thumbnail'] as String?)?.replaceFirst(
      'http:',
      'https:',
    ),
    publishedDate: volumeInfo?['publishedDate'] as String?,
    description: volumeInfo?['description'] as String?,
    pageCount: volumeInfo?['pageCount'] as int?,
  );
}
