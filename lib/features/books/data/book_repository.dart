import 'dart:convert';

import 'package:an_ki/core/config/app_config.dart';
import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/domain/book.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
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
/// Convertit documents et réponses ↔ [Book]. Ni logique métier, ni texte
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

  /// Livre de Google Books pour [isbn] ; null s'il est inconnu. Lève
  /// [BookFailure.network] sans réseau, [BookFailure.quotaExceeded] quand le
  /// quota de l'API est dépassé, [BookFailure.unavailable] pour toute autre
  /// erreur ou réponse illisible.
  Future<Book?> fetchBookByIsbn(String isbn) async {
    // Paramètres encodés : une valeur lue par la caméra ne casse pas l'URL.
    final url = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': 'isbn:$isbn',
      'key': _apiKey,
    });
    final http.Response response;
    try {
      response = await _httpClient.get(url);
    } on http.ClientException catch (e, stack) {
      debugPrint('Google Books unreachable: $e');
      Error.throwWithStackTrace(BookFailure.network, stack);
    } on Exception catch (e, stack) {
      // TLS refusé (portail Wi-Fi, horloge fausse) : IOClient ne l'enveloppe pas.
      debugPrint('Google Books failed: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 429:
        throw BookFailure.quotaExceeded;
      default:
        debugPrint('Google Books HTTP ${response.statusCode}');
        throw BookFailure.unavailable;
    }

    try {
      return switch (json.decode(response.body)) {
        {'items': [final Map<String, dynamic> item, ...]} => _bookFromVolume(
          item,
          isbn,
        ),
        // Aucun résultat : `totalItems` à 0, sans `items` (ou vide).
        {'items': []} => null,
        final Map<String, dynamic> body when !body.containsKey('items') => null,
        _ => throw const FormatException('unexpected volumes shape'),
      };
    } catch (e, stack) {
      // JSON invalide ou champ d'un autre type que prévu.
      debugPrint('Google Books unreadable: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }
  }

  Stream<List<Book>> watchBooks(String uid) {
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
    Book book, {
    required DateTime scannedAt,
  }) async {
    await _books.add(_bookToMap(book, uid: uid, scannedAt: scannedAt));
  }

  /// Marque les livres de [uid], un invité, pour le compte Google [email] qui
  /// va les reprendre ([takeOver]), et renvoie leurs ids. Lus sur le serveur ;
  /// le Future attend l'accusé du serveur.
  Future<List<String>> markForTransfer(String uid, String email) async {
    final snapshot = await _books
        .where('uid', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    await _firestore.writeInBatches(
      snapshot.docs,
      (batch, doc) => batch.update(doc.reference, {'transferTo': email}),
    );
    return [for (final doc in snapshot.docs) doc.id];
  }

  /// Reprend pour [uid] les livres [bookIds] marqués pour lui : ils deviennent
  /// les siens, sans marque.
  Future<void> takeOver(String uid, Iterable<String> bookIds) =>
      _firestore.writeInBatches(
        bookIds,
        (batch, id) => batch.update(_books.doc(id), {
          'uid': uid,
          'transferTo': FieldValue.delete(),
        }),
      );

  /// Efface tous les livres de [uid] (suppression du compte), par lots
  /// d'écritures.
  /// Lu sur le serveur : hors ligne, l'effacement échoue avant de commencer.
  Future<void> deleteAllUserBooks(String uid) async {
    final snapshot = await _books
        .where('uid', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    await _firestore.writeInBatches(
      snapshot.docs,
      (batch, doc) => batch.delete(doc.reference),
    );
  }
}

// Conversions vers le domaine : privées au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
Book _bookFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Book(
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
  Book book, {
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

/// Volume Google Books (`items[n]`) → livre pas encore ajouté à la liste ;
/// sans titre, le titre reste vide et l'UI le formule.
Book _bookFromVolume(Map<String, dynamic> item, String isbn) {
  final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
  final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;

  return Book(
    id: '',
    title: volumeInfo?['title'] as String? ?? '',
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
