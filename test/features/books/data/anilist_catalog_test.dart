import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/anilist_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/series_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AniListCatalog catalogReturning(
  FutureOr<http.Response> Function(http.Request request) handler,
) =>
    AniListCatalog(httpClient: MockClient((request) async => handler(request)));

http.Response json200(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> page(List<Object> media) => {
  'data': {
    'Page': {'media': media},
  },
};

void main() {
  test('posts the name as a variable to the GraphQL endpoint', () async {
    late http.Request sent;
    final catalog = catalogReturning((request) {
      sent = request;
      return json200(page(const []));
    });

    await catalog.searchManga('  One Piece "} ');

    expect(sent.method, 'POST');
    expect(sent.url, Uri.https('graphql.anilist.co', '/'));
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['variables'], {'search': 'One Piece "}'});
    expect(
      body['query'],
      contains(r'media(search: $search, type: MANGA, isAdult: false)'),
    );
  });

  test('a name without letters or digits calls nothing', () async {
    var calls = 0;
    final catalog = catalogReturning((_) {
      calls++;
      return json200(page(const []));
    });

    expect(await catalog.searchManga(' -- '), isEmpty);
    expect(calls, 0);
  });

  test('reads the titles, synonyms and the large cover', () async {
    final catalog = catalogReturning(
      (_) => json200(
        page([
          {
            'title': {
              'romaji': 'Sousou no Frieren',
              'english': 'Frieren: Beyond Journey’s End',
              'native': '葬送のフリーレン',
            },
            'synonyms': ['Frieren', null],
            'coverImage': {
              'extraLarge': 'https://s4.anilist.co/xl.jpg',
              'large': 'https://s4.anilist.co/l.jpg',
            },
          },
          {
            'title': {'romaji': 'Sans image', 'english': null},
            'coverImage': {'extraLarge': 'https://s4.anilist.co/only-xl.jpg'},
          },
          {'title': null, 'synonyms': null, 'coverImage': null},
        ]),
      ),
    );

    expect(await catalog.searchManga('Frieren'), const [
      ArtworkCandidate(
        titles: [
          'Sousou no Frieren',
          'Frieren: Beyond Journey’s End',
          '葬送のフリーレン',
          'Frieren',
        ],
        imageUrl: 'https://s4.anilist.co/l.jpg',
      ),
      ArtworkCandidate(
        titles: ['Sans image'],
        imageUrl: 'https://s4.anilist.co/only-xl.jpg',
      ),
      ArtworkCandidate(titles: [], imageUrl: null),
    ]);
  });

  test('no result is an empty page', () async {
    final catalog = catalogReturning((_) => json200(page(const [])));

    expect(await catalog.searchManga('zzz'), isEmpty);
  });

  group('failures', () {
    Future<void> expectFailure(
      FutureOr<http.Response> Function(http.Request) handler,
      BookFailure failure,
    ) => expectLater(
      catalogReturning(handler).searchManga('One Piece'),
      throwsA(failure),
    );

    test('429 is a quota failure', () async {
      await expectFailure(
        (_) => http.Response('', 429),
        BookFailure.quotaExceeded,
      );
    });

    test('another status is unavailable', () async {
      await expectFailure(
        (_) => http.Response('', 500),
        BookFailure.unavailable,
      );
    });

    test('an unreadable body is unavailable', () async {
      await expectFailure(
        (_) => http.Response('{"data": null}', 200),
        BookFailure.unavailable,
      );
      await expectFailure(
        (_) => http.Response('<html>', 200),
        BookFailure.unavailable,
      );
    });

    test('no network is a network failure', () async {
      await expectFailure(
        (_) => throw http.ClientException('offline'),
        BookFailure.network,
      );
    });

    test('a TLS error is unavailable', () async {
      await expectFailure(
        (_) => throw const HandshakeException('bad clock'),
        BookFailure.unavailable,
      );
    });
  });

  test('the provider uses the shared http client', () async {
    var calls = 0;
    final container = ProviderContainer.test(
      overrides: [
        httpClientProvider.overrideWithValue(
          MockClient((_) async {
            calls++;
            return json200(page(const []));
          }),
        ),
      ],
    );

    await container.read(aniListCatalogProvider).searchManga('One Piece');

    expect(calls, 1);
  });
}
