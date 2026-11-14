import 'dart:async';

import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Délai d'attente d'un catalogue : au rayon, mieux vaut un échec net (le tome
/// reste « à chercher ») qu'un scan qui pend.
const catalogTimeout = Duration(seconds: 10);

/// GET [url] chez le catalogue [source] ; les échecs de transport deviennent
/// des [BookFailure], la pile d'origine conservée. Le code HTTP est laissé à
/// l'appelant : chaque catalogue a ses propres réponses.
///
/// - Pas de réseau, ou [timeout] dépassé : [BookFailure.network].
/// - Autre exception (TLS refusé par un portail Wi-Fi ou une horloge fausse :
///   `IOClient` ne l'enveloppe pas) : [BookFailure.unavailable].
Future<http.Response> getFromCatalog(
  http.Client client,
  Uri url, {
  required String source,
  Duration timeout = catalogTimeout,
}) => _send(() => client.get(url), source: source, timeout: timeout);

/// POST [body] (JSON déjà encodé) à [url] chez le catalogue [source] ; mêmes
/// échecs que [getFromCatalog].
Future<http.Response> postToCatalog(
  http.Client client,
  Uri url, {
  required String body,
  required String source,
  Duration timeout = catalogTimeout,
}) => _send(
  () => client.post(
    url,
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: body,
  ),
  source: source,
  timeout: timeout,
);

Future<http.Response> _send(
  Future<http.Response> Function() request, {
  required String source,
  required Duration timeout,
}) async {
  try {
    return await request().timeout(timeout);
  } on TimeoutException catch (e, stack) {
    debugPrint('$source timed out: $e');
    Error.throwWithStackTrace(BookFailure.network, stack);
  } on http.ClientException catch (e, stack) {
    debugPrint('$source unreachable: $e');
    Error.throwWithStackTrace(BookFailure.network, stack);
  } on Exception catch (e, stack) {
    debugPrint('$source failed: $e');
    Error.throwWithStackTrace(BookFailure.unavailable, stack);
  }
}
