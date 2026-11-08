import 'dart:convert';

import 'package:an_ki/core/config/app_config.dart';
import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/catalog_request.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final googleBooksCatalogProvider = Provider<GoogleBooksCatalog>(
  (ref) => GoogleBooksCatalog(
    httpClient: ref.watch(httpClientProvider),
    apiKey: ref.watch(appConfigProvider).googleBooksApiKey,
  ),
);

/// Catalogue Google Books : les livres récents et les couvertures que la BnF
/// n'a pas.
///
/// Convertit une réponse `volumes` ↔ [BookMetadata]. Ni logique métier, ni
/// texte d'UI, ni état. Ni description ni résumé n'est gardé (taille, et CGU de
/// Google).
class GoogleBooksCatalog {
  GoogleBooksCatalog({required this._httpClient, required this._apiKey});

  final http.Client _httpClient;

  /// Clé Google Books, lue depuis `--dart-define` par [AppConfig].
  final String _apiKey;

  /// Métadonnées de Google Books pour [isbn] ; null s'il est inconnu, ou si
  /// [isbn] n'est pas un ISBN-13 (aucun appel alors : `isbn:` accepte des
  /// opérateurs de recherche, une valeur libre trouverait un autre livre). Lève
  /// [BookFailure.network] sans réseau ou au-delà de [catalogTimeout],
  /// [BookFailure.quotaExceeded] quand le quota de l'API est dépassé,
  /// [BookFailure.unavailable] pour toute autre erreur ou réponse illisible.
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    if (!isBookIsbn(isbn)) return null;
    // Paramètres encodés : une valeur lue par la caméra ne casse pas l'URL.
    final url = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': 'isbn:$isbn',
      'key': _apiKey,
    });
    final response = await getFromCatalog(
      _httpClient,
      url,
      source: 'Google Books',
    );

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
        {'items': [final Map<String, dynamic> item, ...]} =>
          _metadataFromVolume(item),
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
}

/// Volume Google Books (`items[n]`) → métadonnées ; sans titre, le titre reste
/// vide et l'UI le formule.
///
/// `seriesInfo` ne nomme pas la série (il faudrait un second appel avec son
/// `seriesId`) : seul le numéro est repris, `seriesTitle` reste null.
BookMetadata _metadataFromVolume(Map<String, dynamic> item) {
  final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
  final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;
  final seriesInfo = volumeInfo?['seriesInfo'] as Map<String, dynamic>?;

  return BookMetadata(
    title: volumeInfo?['title'] as String? ?? '',
    subtitle: volumeInfo?['subtitle'] as String?,
    authors: List<String>.from(
      volumeInfo?['authors'] as List<dynamic>? ?? const [],
    ),
    publisher: volumeInfo?['publisher'] as String?,
    publishedDate: volumeInfo?['publishedDate'] as String?,
    imageUrl: (imageLinks?['thumbnail'] as String?)?.replaceFirst(
      RegExp('^http:'),
      'https:',
    ),
    seriesNumber: _seriesNumber(seriesInfo),
  );
}

/// Numéro entier du tome d'après `seriesInfo` : `bookDisplayNumber` (texte),
/// sinon l'`orderNumber` de la première série.
int? _seriesNumber(Map<String, dynamic>? seriesInfo) {
  if (seriesInfo == null) return null;
  final display = seriesInfo['bookDisplayNumber'] as String?;
  final fromDisplay = display == null ? null : parseVolumeNumber(display);
  if (fromDisplay != null) return fromDisplay;
  final series = seriesInfo['volumeSeries'] as List<dynamic>?;
  final order = (series?.firstOrNull as Map<String, dynamic>?)?['orderNumber'];
  return switch (order) {
    final int number => parseVolumeNumber('$number'),
    final String text => parseVolumeNumber(text),
    _ => null,
  };
}
