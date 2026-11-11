import 'dart:convert';

import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/catalog_request.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

final bnfCatalogProvider = Provider<BnfCatalog>(
  (ref) => BnfCatalog(httpClient: ref.watch(httpClientProvider)),
);

/// Catalogue de la Bibliothèque nationale de France, interrogé en SRU : sans
/// clé (licence ouverte), et les notices disent la série et le numéro du tome
/// dans des champs structurés (UNIMARC 225 et 461).
///
/// Convertit une réponse `unimarcxchange` ↔ [BookMetadata]. Ni logique métier,
/// ni texte d'UI, ni état. Une notice naît au dépôt légal : un tome paru depuis
/// quelques jours peut manquer.
class BnfCatalog {
  BnfCatalog({required this._httpClient});

  final http.Client _httpClient;

  /// Notice de la BnF pour [isbn] (un ISBN-13, voir `normalizeIsbn`) ; null
  /// quand elle n'en a pas, ou quand [isbn] n'est pas un ISBN-13 (aucun appel
  /// alors : la valeur entre dans une requête CQL).
  ///
  /// Lève [BookFailure.network] sans réseau ou au-delà de [catalogTimeout],
  /// [BookFailure.unavailable] pour toute autre erreur, réponse non-200 ou
  /// réponse illisible. Le quota n'existe pas ici : jamais
  /// [BookFailure.quotaExceeded].
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    if (!isBookIsbn(isbn)) return null;
    // Paramètres encodés par `Uri.https` ; l'ISBN est vérifié ci-dessus.
    final url = Uri.https('catalogue.bnf.fr', '/api/SRU', {
      'version': '1.2',
      'operation': 'searchRetrieve',
      'query': 'bib.isbn all "$isbn"',
      'recordSchema': 'unimarcxchange',
      'maximumRecords': '5',
    });
    final response = await getFromCatalog(_httpClient, url, source: 'BnF');
    if (response.statusCode != 200) {
      debugPrint('BnF HTTP ${response.statusCode}');
      throw BookFailure.unavailable;
    }

    try {
      return _metadataFromResponse(utf8.decode(response.bodyBytes), isbn);
    } catch (e, stack) {
      // XML invalide, forme inattendue ou diagnostic SRU.
      debugPrint('BnF unreadable: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }
  }

  /// Notices dont le titre contient [seriesName] et [number] (« One Piece
  /// 109 ») : de quoi savoir si ce tome est paru, ou quand il paraîtra quand
  /// l'éditeur a déposé ses métadonnées avant la sortie. Vide quand la BnF
  /// n'a rien, ou pour un nom sans lettre ni chiffre (aucun appel alors).
  ///
  /// Les notices ne sont pas filtrées : à l'appelant de vérifier la série et
  /// le numéro (`guessVolume`), car la recherche porte sur des mots. Mêmes
  /// échecs que [fetchByIsbn].
  Future<List<BookMetadata>> searchVolume(String seriesName, int number) async {
    // Des mots seulement : la valeur entre dans une chaîne CQL entre
    // guillemets, où `"`, `\`, `*`, `?` et `^` ont un sens.
    final words = seriesName.replaceAll(_notWord, ' ').trim();
    if (words.isEmpty || number < 1) return const [];
    final url = Uri.https('catalogue.bnf.fr', '/api/SRU', {
      'version': '1.2',
      'operation': 'searchRetrieve',
      'query': 'bib.title all "$words $number"',
      'recordSchema': 'unimarcxchange',
      'maximumRecords': '$_searchedRecords',
    });
    final response = await getFromCatalog(_httpClient, url, source: 'BnF');
    if (response.statusCode != 200) {
      debugPrint('BnF HTTP ${response.statusCode}');
      throw BookFailure.unavailable;
    }

    try {
      return _recordsFromResponse(utf8.decode(response.bodyBytes))
          .map((record) => _metadataFromRecord(record, null))
          .nonNulls
          .toList();
    } catch (e, stack) {
      debugPrint('BnF unreadable: $e');
      Error.throwWithStackTrace(BookFailure.unavailable, stack);
    }
  }
}

/// Notices lues par [BnfCatalog.searchVolume] : un nom courant (« Naruto 1 »)
/// en ramène des dizaines, éditions spéciales et dérivés compris.
const _searchedRecords = 20;

/// Ce qui n'est ni une lettre ni un chiffre.
final _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

const _marcNamespace = 'info:lc/xmlns/marcxchange-v2';

/// Réponse SRU → métadonnées de la première notice qui est celle de [isbn] ;
/// null sans notice. La BnF cherche aussi dans d'autres champs : la bonne
/// notice n'est pas toujours la première.
BookMetadata? _metadataFromResponse(String body, String isbn) {
  for (final record in _recordsFromResponse(body)) {
    if (_metadataFromRecord(record, isbn) case final metadata?) {
      return metadata;
    }
  }
  return null;
}

/// Notices UNIMARC d'une réponse SRU ; lève [FormatException] pour une
/// réponse qui n'en est pas une, ou un diagnostic sans notice (un diagnostic
/// accompagné de notices n'est pas fatal).
Iterable<XmlElement> _recordsFromResponse(String body) {
  final root = XmlDocument.parse(body).rootElement;
  if (root.name.local != 'searchRetrieveResponse') {
    throw const FormatException('not an SRU response');
  }
  final records = root.findAllElements('record', namespaceUri: _marcNamespace);
  if (records.isEmpty &&
      root.findAllElements('diagnostics', namespaceUri: '*').isNotEmpty) {
    throw const FormatException('SRU diagnostic');
  }
  return records;
}

/// Notice UNIMARC → métadonnées ; null si elle n'a pas de titre, ou si elle
/// est celle d'un autre ISBN que [isbn] (quand il est donné).
BookMetadata? _metadataFromRecord(XmlElement record, String? isbn) {
  final fields = [
    for (final field in record.findElements(
      'datafield',
      namespaceUri: _marcNamespace,
    ))
      _DataField.of(field),
  ];
  List<_DataField> tagged(String tag) => [
    for (final field in fields)
      if (field.tag == tag) field,
  ];

  // 010 $a et 073 $a : si la notice donne des ISBN, l'un doit être celui
  // demandé (la BnF cherche aussi dans d'autres champs).
  final noticeIsbns = <String>{
    for (final field in [...tagged('010'), ...tagged('073')])
      ..._isbnsOf(field),
  };
  if (isbn != null && noticeIsbns.isNotEmpty && !noticeIsbns.contains(isbn)) {
    return null;
  }

  // 200 : $a titre, $e complément du titre ; $h et $i quand le titre est celui
  // d'une partie (« $a Blacksad $h 7 $i Alors, tout tombe »).
  final titleField = tagged('200').firstOrNull;
  if (titleField == null) return null;
  final part = titleField.first('i');
  final title = part ?? titleField.first('a');
  if (title == null) return null;
  final partSeries = part == null || titleField.first('a') == null
      ? null
      : _Series(
          titleField.first('a')!,
          parseVolumeNumber(titleField.first('h') ?? ''),
        );

  final authors = <String>[
    for (final field in [...tagged('700'), ...tagged('701'), ...tagged('702')])
      ?_authorName(field),
  ];

  final publication = _publicationField(tagged('214'), tagged('210'));
  final series = _chooseSeries(
    linked: [
      for (final field in tagged('461'))
        if (field.first('t') case final name?)
          _Series(name, parseVolumeNumber(field.first('v') ?? '')),
    ],
    collections: [
      for (final field in tagged('225'))
        // Une collection d'éditeur porte un ISSN ($x) : pas une série.
        if (field.first('a') case final name? when field.first('x') == null)
          _Series(name, parseVolumeNumber(field.first('v') ?? '')),
    ],
    part: partSeries,
  );

  return BookMetadata(
    title: title,
    subtitle: titleField.first('e'),
    authors: authors.toSet().toList(),
    publisher: publication?.first('c'),
    publishedDate: _publicationDate(publication?.first('d')),
    seriesTitle: series?.name,
    seriesNumber: series?.number,
  );
}

/// Série d'une notice, avec son numéro quand il est entier.
class _Series {
  const _Series(this.name, this.number);

  final String name;
  final int? number;
}

/// La série d'une notice : le nom du 461 (le lien de série), sinon celui du
/// premier champ numéroté (225, puis 200), sinon le premier nom ; le numéro du
/// premier champ numéroté (461, 225, 200). Le nom vient du 461 même quand seul
/// un 225 porte le numéro : tous les tomes d'une série gardent ainsi le même
/// nom, donc la même clé.
_Series? _chooseSeries({
  required List<_Series> linked,
  required List<_Series> collections,
  required _Series? part,
}) {
  final all = [...linked, ...collections, ?part];
  if (all.isEmpty) return null;
  final numbered = all.where((series) => series.number != null).firstOrNull;
  final named = linked.firstOrNull ?? numbered ?? all.first;
  return _Series(named.name, numbered?.number);
}

/// Champ d'édition : le 214 de publication (#0, puis sans indicateur), sinon le
/// 210, sinon le 214 de copyright (#4, « cop. 2018 »). Jamais celui
/// d'impression (#3), de production (#1) ni de diffusion (#2).
_DataField? _publicationField(List<_DataField> f214, List<_DataField> f210) {
  for (final indicator in const ['0', ' ']) {
    for (final field in f214) {
      if (field.indicator2 == indicator) return field;
    }
  }
  if (f210.isNotEmpty) return f210.first;
  for (final field in f214) {
    if (field.indicator2 == '4') return field;
  }
  return null;
}

/// Date d'édition au format ISO : `2026-09-23` pour « 23/09/2026 » (les
/// métadonnées qu'un éditeur dépose avant la sortie), `2026-09` pour
/// « 09/2026 », sinon le premier millésime de quatre chiffres (« DL 2018 » →
/// `2018`). Un jour ou un mois impossible ne garde que l'année.
String? _publicationDate(String? text) {
  if (text == null) return null;
  if (_dayMonthYear.firstMatch(text) case final match?) {
    final day = match.group(1);
    final month = match.group(2)!.padLeft(2, '0');
    final year = match.group(3)!;
    final iso = day == null
        ? '$year-$month'
        : '$year-$month-${day.padLeft(2, '0')}';
    if (ReleaseDate.tryParse(iso) != null) return iso;
    return year;
  }
  return RegExp(r'\d{4}').firstMatch(text)?.group(0);
}

/// « 23/09/2026 », « 3/9/2026 », « 09/2026 » ; le jour est facultatif.
final _dayMonthYear = RegExp(r'(?<!\d)(?:(\d{1,2})/)?(\d{1,2})/(\d{4})(?!\d)');

/// Fonctions qui ne sont pas celles d'un auteur : traducteur, préfacier,
/// postfacier.
const _notAuthorRoles = {'730', '080', '075'};

/// « Prénom Nom » d'un champ 700/701/702 ; null pour un traducteur ou un
/// préfacier, ou sans nom.
String? _authorName(_DataField field) {
  final role = field.first('4');
  if (role != null && _notAuthorRoles.contains(role)) return null;
  final surname = field.first('a');
  if (surname == null) return null;
  final forename = field.first('b');
  return forename == null ? surname : '$forename $surname';
}

/// Champ de notice UNIMARC : étiquette, second indicateur et sous-champs.
class _DataField {
  _DataField(this.tag, this.indicator2, this._subfields);

  factory _DataField.of(XmlElement field) => _DataField(
    field.getAttribute('tag') ?? '',
    field.getAttribute('ind2') ?? ' ',
    [
      for (final sub in field.findElements(
        'subfield',
        namespaceUri: _marcNamespace,
      ))
        (sub.getAttribute('code') ?? '', _text(sub.innerText)),
    ],
  );

  final String tag;
  final String indicator2;
  final List<(String, String)> _subfields;

  /// Première valeur non vide du sous-champ [code].
  String? first(String code) => all(code).firstOrNull;

  /// Valeurs non vides du sous-champ [code], dans l'ordre.
  Iterable<String> all(String code) sync* {
    for (final (c, value) in _subfields) {
      if (c == code && value.isNotEmpty) yield value;
    }
  }
}

/// [raw] sans caractères de contrôle (marques de non-tri `U+0088`/`U+0089`),
/// espaces réduits.
String _text(String raw) => raw
    .replaceAll(RegExp(r'[\u0080-\u009F]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// ISBN-13 normalisés d'un champ 010 ou 073 : `$a` (valide) et `$z` (erroné,
/// mais c'est celui imprimé sur certains livres, donc celui du code-barres).
Iterable<String> _isbnsOf(_DataField field) sync* {
  for (final code in const ['a', 'z']) {
    for (final raw in field.all(code)) {
      if (normalizeIsbn(raw) case final isbn?) yield isbn;
    }
  }
}
