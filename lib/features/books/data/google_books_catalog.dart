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

    _ensureOk(response);

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

  /// Éditions françaises dont le titre contient [seriesName], avec [number]
  /// parmi les mots cherchés (« One Piece 114 ») : de quoi lire la date
  /// qu'un éditeur annonce avant la sortie, que la BnF n'a pas encore (D14).
  /// Vide quand Google n'a rien, ou pour un nom sans lettre ni chiffre (aucun
  /// appel alors).
  ///
  /// `langRestrict` ne suffit pas : Google rend aussi d'autres langues, que
  /// seul le champ `language` écarte. Le reste n'est pas filtré : à
  /// l'appelant de vérifier la série et le numéro (`guessVolume`). Mêmes
  /// échecs que [fetchByIsbn].
  Future<List<BookMetadata>> searchVolume(String seriesName, int number) async {
    // Des mots seulement : la valeur entre entre guillemets dans `intitle:`.
    final words = seriesName.replaceAll(_notWord, ' ').trim();
    if (words.isEmpty || number < 1) return const [];
    final url = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': 'intitle:"$words" $number',
      'langRestrict': 'fr',
      'printType': 'books',
      'maxResults': '$_searchedVolumes',
      'key': _apiKey,
    });
    final response = await getFromCatalog(
      _httpClient,
      url,
      source: 'Google Books',
    );

    _ensureOk(response);

    try {
      return switch (json.decode(response.body)) {
        {'items': final List<dynamic> items} => [
          for (final item in items.cast<Map<String, dynamic>>())
            if ((item['volumeInfo'] as Map<String, dynamic>?)?['language'] ==
                'fr')
              _metadataFromVolume(item),
        ],
        // Aucun résultat : `totalItems` à 0, sans `items`.
        final Map<String, dynamic> body when !body.containsKey('items') =>
          const <BookMetadata>[],
        _ => throw const FormatException('unexpected volumes shape'),
      };
    } catch (e, stack) {
      // JSON invalide ou champ d'un autre type que prévu.
      debugPrint('Google Books unreadable: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }
  }
}

/// Lève l'échec que dit le code HTTP de [response] : [BookFailure.quotaExceeded]
/// pour 429, [BookFailure.unavailable] pour tout autre code que 200.
void _ensureOk(http.Response response) {
  switch (response.statusCode) {
    case 200:
      return;
    case 429:
      throw BookFailure.quotaExceeded;
    default:
      debugPrint('Google Books HTTP ${response.statusCode}');
      throw BookFailure.unavailable;
  }
}

/// Volumes lus par [GoogleBooksCatalog.searchVolume] : la mesure de l'étape 9
/// trouvait le bon tome parmi les huit premiers.
const _searchedVolumes = 20;

/// Ce qui n'est ni une lettre ni un chiffre.
final _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

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
