import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:an_ki/core/config/app_config.dart';
import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GoogleBooksCatalog catalogReturning(
  http.Response Function(http.Request request) handler,
) => GoogleBooksCatalog(
  httpClient: MockClient((request) async => handler(request)),
  apiKey: 'test-key',
);

http.Response json200(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> volumes(Map<String, Object> volumeInfo) => {
  'totalItems': 1,
  'items': [
    {'volumeInfo': volumeInfo},
  ],
};

const _isbn = '9782723492607';

void main() {
  group('request', () {
    test('searches the isbn with the key', () async {
      late Uri sent;
      final catalog = catalogReturning((request) {
        sent = request.url;
        return json200({'totalItems': 0});
      });

      await catalog.fetchByIsbn(_isbn);

      expect(sent.scheme, 'https');
      expect(sent.host, 'www.googleapis.com');
      expect(sent.path, '/books/v1/volumes');
      expect(sent.queryParameters, {'q': 'isbn:$_isbn', 'key': 'test-key'});
    });

    test(
      'does not call the network for something that is not an ISBN-13',
      () async {
        var calls = 0;
        final catalog = catalogReturning((_) {
          calls++;
          return json200({'totalItems': 0});
        });

        for (final text in [
          '',
          '123',
          '0451524934',
          'x intitle:y',
          '9782723492607&key=stolen',
        ]) {
          expect(await catalog.fetchByIsbn(text), isNull, reason: text);
        }
        expect(calls, 0);
      },
    );
  });

  group('mapping', () {
    test('a complete volume', () async {
      final catalog = catalogReturning(
        (_) => json200(
          volumes({
            'title': 'One Piece - Tome 15',
            'subtitle': 'Droit devant !!',
            'authors': ['Eiichiro Oda'],
            'publisher': 'Glénat',
            'publishedDate': '2013-06-28',
            'description': 'Un long résumé qu\'on ne garde pas.',
            'pageCount': 192,
            'imageLinks': {'thumbnail': 'http://books.google.com/cover.jpg'},
            'seriesInfo': {'bookDisplayNumber': '15'},
          }),
        ),
      );

      expect(
        await catalog.fetchByIsbn(_isbn),
        const BookMetadata(
          title: 'One Piece - Tome 15',
          subtitle: 'Droit devant !!',
          authors: ['Eiichiro Oda'],
          publisher: 'Glénat',
          publishedDate: '2013-06-28',
          imageUrl: 'https://books.google.com/cover.jpg',
          seriesNumber: 15,
        ),
      );
    });

    test('a minimal volume', () async {
      final catalog = catalogReturning(
        (_) => json200(volumes({'title': 'Blacksad'})),
      );

      expect(
        await catalog.fetchByIsbn(_isbn),
        const BookMetadata(title: 'Blacksad', authors: []),
      );
    });

    test('a volume without volumeInfo has an empty title', () async {
      final catalog = catalogReturning(
        (_) => json200({
          'items': [<String, Object>{}],
        }),
      );

      expect(
        await catalog.fetchByIsbn(_isbn),
        const BookMetadata(title: '', authors: []),
      );
    });

    test('only the first item is read', () async {
      final catalog = catalogReturning(
        (_) => json200({
          'items': [
            {
              'volumeInfo': {'title': 'First'},
            },
            {
              'volumeInfo': {'title': 'Second'},
            },
          ],
        }),
      );

      expect((await catalog.fetchByIsbn(_isbn))!.title, 'First');
    });

    test('an https cover is kept, an http one upgraded', () async {
      Future<String?> coverOf(String url) async {
        final catalog = catalogReturning(
          (_) => json200(
            volumes({
              'title': 'T',
              'imageLinks': {'thumbnail': url},
            }),
          ),
        );
        return (await catalog.fetchByIsbn(_isbn))!.imageUrl;
      }

      expect(await coverOf('https://c/1.jpg'), 'https://c/1.jpg');
      expect(
        await coverOf('http://c/1.jpg?x=http://y'),
        'https://c/1.jpg?x=http://y',
      );
    });

    group('seriesInfo', () {
      Future<int?> numberOf(Map<String, Object> seriesInfo) async {
        final catalog = catalogReturning(
          (_) => json200(volumes({'title': 'T', 'seriesInfo': seriesInfo})),
        );
        return (await catalog.fetchByIsbn(_isbn))!.seriesNumber;
      }

      test('reads the display number', () async {
        expect(await numberOf({'bookDisplayNumber': '3'}), 3);
        expect(await numberOf({'bookDisplayNumber': 'Tome 12'}), 12);
      });

      test('falls back to the order number of the first series', () async {
        expect(
          await numberOf({
            'volumeSeries': [
              {'seriesId': 'abc', 'orderNumber': 7},
            ],
          }),
          7,
        );
        expect(
          await numberOf({
            'bookDisplayNumber': '10.5',
            'volumeSeries': [
              {'orderNumber': '4'},
            ],
          }),
          4,
        );
      });

      test('has no number when nothing usable is there', () async {
        expect(await numberOf({}), isNull);
        expect(await numberOf({'bookDisplayNumber': '10.5'}), isNull);
        expect(await numberOf({'volumeSeries': <Object>[]}), isNull);
        expect(
          await numberOf({
            'volumeSeries': [
              {'orderNumber': 2024.5},
            ],
          }),
          isNull,
        );
      });

      test('never names the series', () async {
        final catalog = catalogReturning(
          (_) => json200(
            volumes({
              'title': 'T',
              'seriesInfo': {
                'bookDisplayNumber': '3',
                'shortSeriesBookTitle': 'Catching Fire',
              },
            }),
          ),
        );

        expect((await catalog.fetchByIsbn(_isbn))!.seriesTitle, isNull);
      });
    });
  });

  group('no result', () {
    test('totalItems at 0 without items', () async {
      final catalog = catalogReturning((_) => json200({'totalItems': 0}));

      expect(await catalog.fetchByIsbn(_isbn), isNull);
    });

    test('an empty items list', () async {
      final catalog = catalogReturning(
        (_) => json200({'totalItems': 0, 'items': <Object>[]}),
      );

      expect(await catalog.fetchByIsbn(_isbn), isNull);
    });
  });

  group('failures', () {
    Future<Object?> failureOf(GoogleBooksCatalog catalog) async {
      try {
        await catalog.fetchByIsbn(_isbn);
      } on BookFailure catch (failure) {
        return failure;
      }
      return null;
    }

    test('429: quotaExceeded', () async {
      final catalog = catalogReturning((_) => http.Response('', 429));

      expect(await failureOf(catalog), BookFailure.quotaExceeded);
    });

    test('no network: network', () async {
      final catalog = GoogleBooksCatalog(
        httpClient: MockClient(
          (_) async => throw http.ClientException('Failed host lookup'),
        ),
        apiKey: 'test-key',
      );

      expect(await failureOf(catalog), BookFailure.network);
    });

    test('a timeout: network', () async {
      final catalog = GoogleBooksCatalog(
        httpClient: MockClient((_) async => throw TimeoutException('slow')),
        apiKey: 'test-key',
      );

      expect(await failureOf(catalog), BookFailure.network);
    });

    test('a TLS failure: unavailable', () async {
      final catalog = GoogleBooksCatalog(
        httpClient: MockClient(
          (_) async => throw const HandshakeException('bad certificate'),
        ),
        apiKey: 'test-key',
      );

      expect(await failureOf(catalog), BookFailure.unavailable);
    });

    test('another HTTP error: unavailable', () async {
      for (final status in [400, 403, 404, 500, 503]) {
        final catalog = catalogReturning((_) => http.Response('', status));

        expect(
          await failureOf(catalog),
          BookFailure.unavailable,
          reason: '$status',
        );
      }
    });

    test('unreadable bodies: unavailable', () async {
      final bodies = [
        '<html>',
        '',
        '[]',
        '{"items": "nope"}',
        '{"items": [1]}',
        '{"items": [{"volumeInfo": {"title": 5}}]}',
        '{"items": [{"volumeInfo": {"authors": "x"}}]}',
        '{"items": [{"volumeInfo": {"seriesInfo": {"bookDisplayNumber": 3}}}]}',
      ];
      for (final body in bodies) {
        final catalog = catalogReturning((_) => http.Response(body, 200));

        expect(await failureOf(catalog), BookFailure.unavailable, reason: body);
      }
    });
  });

  group('searchVolume', () {
    Map<String, Object> item(String title, String language, {String? date}) => {
      'volumeInfo': {
        'title': title,
        'language': language,
        'publishedDate': ?date,
      },
    };

    test('searches the title words and the number, in French books', () async {
      late Uri sent;
      final catalog = catalogReturning((request) {
        sent = request.url;
        return json200({'totalItems': 0});
      });

      expect(await catalog.searchVolume('Kaiju n° 8 "x"', 17), isEmpty);

      expect(sent.host, 'www.googleapis.com');
      expect(sent.path, '/books/v1/volumes');
      expect(sent.queryParameters, {
        'q': 'intitle:"Kaiju n 8 x" 17',
        'langRestrict': 'fr',
        'printType': 'books',
        'maxResults': '20',
        'key': 'test-key',
      });
    });

    test('nothing to search: no call', () async {
      var calls = 0;
      final catalog = catalogReturning((_) {
        calls++;
        return json200({'totalItems': 0});
      });

      expect(await catalog.searchVolume(' -- ', 3), isEmpty);
      expect(await catalog.searchVolume('One Piece', 0), isEmpty);
      expect(calls, 0);
    });

    test('keeps the French editions only, as Google gives them', () async {
      final catalog = catalogReturning(
        (_) => json200({
          'totalItems': 3,
          'items': [
            item(
              'One Piece - Édition originale - Tome 114',
              'fr',
              date: '2026-12-02',
            ),
            item('One Piece, Vol. 114', 'en', date: '2027-03-02'),
            {
              'volumeInfo': <String, Object>{'title': 'Sans langue'},
            },
            item('One Piece 114', 'de'),
          ],
        }),
      );

      expect(await catalog.searchVolume('One Piece', 114), [
        const BookMetadata(
          title: 'One Piece - Édition originale - Tome 114',
          authors: [],
          publishedDate: '2026-12-02',
        ),
      ]);
    });

    test('failures: quota, other errors, unreadable bodies', () async {
      Future<Object?> failureOf(http.Response response) async {
        try {
          await catalogReturning((_) => response)
              .searchVolume('One Piece', 114);
          return null;
        } on BookFailure catch (failure) {
          return failure;
        }
      }

      expect(
        await failureOf(http.Response('', 429)),
        BookFailure.quotaExceeded,
      );
      expect(await failureOf(http.Response('', 503)), BookFailure.unavailable);
      for (final body in ['not json', '[]', '{"items": 3}', '{"items": [1]}']) {
        expect(
          await failureOf(http.Response(body, 200)),
          BookFailure.unavailable,
          reason: body,
        );
      }
    });
  });

  test('the provider reads the key from the app config', () async {
    late Uri sent;
    final container = ProviderContainer.test(
      overrides: [
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            sent = request.url;
            return json200({'totalItems': 0});
          }),
        ),
        appConfigProvider.overrideWithValue(
          const AppConfig(googleBooksApiKey: 'dummy-key'),
        ),
      ],
    );

    await container.read(googleBooksCatalogProvider).fetchByIsbn(_isbn);

    expect(sent.queryParameters['key'], 'dummy-key');
  });
}
