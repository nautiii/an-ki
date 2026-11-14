import 'dart:convert';

import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/catalog_request.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/series_artwork.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final aniListCatalogProvider = Provider<AniListCatalog>(
  (ref) => AniListCatalog(httpClient: ref.watch(httpClientProvider)),
);

/// AniList (API GraphQL publique, sans clé) : l'image d'une série de manga
/// (D15). Une requête par série ; ni logique métier, ni texte d'UI, ni état.
class AniListCatalog {
  AniListCatalog({required this._httpClient});

  final http.Client _httpClient;

  /// Mangas (et romans) qu'AniList trouve pour [name], les plus proches
  /// d'abord ; vide pour un nom sans lettre ni chiffre (aucun appel alors).
  /// À l'appelant de vérifier le titre (`matchArtwork`).
  ///
  /// Lève [BookFailure.network] sans réseau ou au-delà de [catalogTimeout],
  /// [BookFailure.quotaExceeded] au-delà du débit permis (HTTP 429),
  /// [BookFailure.unavailable] pour toute autre erreur ou réponse illisible.
  Future<List<ArtworkCandidate>> searchManga(String name) async {
    final search = name.trim();
    if (!_word.hasMatch(search)) return const [];
    final response = await postToCatalog(
      _httpClient,
      Uri.https('graphql.anilist.co', '/'),
      // Le nom passe en variable : jamais interpolé dans la requête.
      body: json.encode({
        'query': _query,
        'variables': {'search': search},
      }),
      source: 'AniList',
    );
    switch (response.statusCode) {
      case 200:
        break;
      case 429:
        throw BookFailure.quotaExceeded;
      default:
        debugPrint('AniList HTTP ${response.statusCode}');
        throw BookFailure.unavailable;
    }
    try {
      return switch (json.decode(utf8.decode(response.bodyBytes))) {
        {'data': {'Page': {'media': final List<dynamic> media}}} => [
          for (final item in media.cast<Map<String, dynamic>>())
            _candidateOf(item),
        ],
        _ => throw const FormatException('unexpected AniList shape'),
      };
    } catch (e, stack) {
      debugPrint('AniList unreadable: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }
  }
}

/// Une lettre ou un chiffre.
final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Cinq œuvres au plus, par pertinence (tri par défaut d'AniList), jamais
/// une œuvre pour adultes. Aucun résultat : `media` vide, en 200.
const _query = r'''
query ($search: String) {
  Page(perPage: 5) {
    media(search: $search, type: MANGA, isAdult: false) {
      title { romaji english native }
      synonyms
      coverImage { extraLarge large }
    }
  }
}''';

ArtworkCandidate _candidateOf(Map<String, dynamic> media) {
  final title = media['title'] as Map<String, dynamic>?;
  final cover = media['coverImage'] as Map<String, dynamic>?;
  return ArtworkCandidate(
    titles: [
      for (final key in const ['romaji', 'english', 'native'])
        if (title?[key] case final String text) text,
      for (final synonym in media['synonyms'] as List<dynamic>? ?? const [])
        if (synonym case final String text) text,
    ],
    // `large` (~230 px de large) suffit à une vignette, `extraLarge` à l'en-tête.
    imageUrl: cover?['large'] as String? ?? cover?['extraLarge'] as String?,
  );
}
