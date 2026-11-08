import 'dart:async';
import 'dart:io';

import 'package:an_ki/features/books/data/catalog_request.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _url = Uri.https('catalogue.example', '/api');

/// Échec levé par [call], ou null s'il aboutit.
Future<BookFailure?> failureOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on BookFailure catch (failure) {
    return failure;
  }
  return null;
}

void main() {
  test('returns the response, whatever its status', () async {
    final client = MockClient((_) async => http.Response('corps', 503));

    final response = await getFromCatalog(client, _url, source: 'Test');

    expect(response.statusCode, 503);
    expect(response.body, 'corps');
  });

  test('a request that never answers is cut at the timeout', () async {
    final never = Completer<http.Response>();
    final client = MockClient((_) => never.future);

    final failure = await failureOf(
      () => getFromCatalog(
        client,
        _url,
        source: 'Test',
        timeout: const Duration(milliseconds: 20),
      ),
    );

    expect(failure, BookFailure.network);
  });

  test('the default timeout is long enough for a slow mobile network', () {
    expect(catalogTimeout, const Duration(seconds: 10));
  });

  test('a ClientException is a network failure', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('Failed host lookup'),
    );

    expect(
      await failureOf(() => getFromCatalog(client, _url, source: 'Test')),
      BookFailure.network,
    );
  });

  test('another exception, a TLS refusal for one, is unavailable', () async {
    final client = MockClient(
      (_) async => throw const HandshakeException('bad certificate'),
    );

    expect(
      await failureOf(() => getFromCatalog(client, _url, source: 'Test')),
      BookFailure.unavailable,
    );
  });

  test('keeps the stack trace of the original error', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('Failed host lookup'),
    );

    StackTrace? stack;
    try {
      await getFromCatalog(client, _url, source: 'Test');
    } on BookFailure catch (_, trace) {
      stack = trace;
    }

    // Le MockClient lève depuis ce fichier : la pile d'origine le mentionne.
    expect(stack.toString(), contains('catalog_request_test.dart'));
  });
}
