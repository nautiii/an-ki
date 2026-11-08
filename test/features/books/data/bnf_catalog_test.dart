import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:an_ki/core/providers/http_client_provider.dart';
import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _xmlHeaders = {'content-type': 'text/xml;charset=UTF-8'};

/// Réponse réelle de la BnF, enregistrée le 8 novembre 2026.
String fixture(String name) =>
    File('test/features/books/data/fixtures/$name').readAsStringSync();

/// Réponse SRU à plusieurs notices, chacune faite des champs UNIMARC donnés.
String sruWithRecords(List<String> recordsFields, {String diagnostics = ''}) {
  final records = recordsFields
      .map(
        (fields) =>
            '<srw:record><srw:recordData>'
            '<mxc:record xmlns:mxc="info:lc/xmlns/marcxchange-v2" format="UNIMARC">'
            '$fields</mxc:record></srw:recordData></srw:record>',
      )
      .join();
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/" '
      'xmlns:diag="http://www.loc.gov/zing/srw/diagnostic/">'
      '<srw:records>$records</srw:records>$diagnostics'
      '</srw:searchRetrieveResponse>';
}

/// Réponse SRU à une notice faite de [fields] (le XML des champs UNIMARC).
String sruWith(String fields) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/">
<srw:version>1.2</srw:version>
<srw:numberOfRecords>1</srw:numberOfRecords>
<srw:records><srw:record><srw:recordSchema>marcxchange</srw:recordSchema>
<srw:recordData>
<mxc:record xmlns:mxc="info:lc/xmlns/marcxchange-v2" format="UNIMARC" type="Bibliographic">
$fields
</mxc:record>
</srw:recordData></srw:record></srw:records>
</srw:searchRetrieveResponse>''';

/// Champ UNIMARC `tag` (indicateur 2 = [ind2]) et ses sous-champs.
String field(String tag, Map<String, String> subfields, {String ind2 = ' '}) =>
    '<mxc:datafield tag="$tag" ind1=" " ind2="$ind2">'
    '${subfields.entries.map((e) => '<mxc:subfield code="${e.key}">${e.value}</mxc:subfield>').join()}'
    '</mxc:datafield>';

BnfCatalog catalogReturning(
  http.Response Function(http.Request request) handler,
) => BnfCatalog(httpClient: MockClient((request) async => handler(request)));

http.Response xml(String body) =>
    http.Response(body, 200, headers: _xmlHeaders);

BnfCatalog catalogAnswering(String body) => catalogReturning((_) => xml(body));

const _isbn = '9782723492607';

void main() {
  group('request', () {
    test('asks the SRU endpoint for a few unimarcxchange records', () async {
      late Uri sent;
      final catalog = catalogReturning((request) {
        sent = request.url;
        return xml(fixture('bnf_no_record.xml'));
      });

      await catalog.fetchByIsbn(_isbn);

      expect(sent.scheme, 'https');
      expect(sent.host, 'catalogue.bnf.fr');
      expect(sent.path, '/api/SRU');
      expect(sent.queryParameters, {
        'version': '1.2',
        'operation': 'searchRetrieve',
        'query': 'bib.isbn all "$_isbn"',
        'recordSchema': 'unimarcxchange',
        'maximumRecords': '5',
      });
    });

    test(
      'does not call the network for something that is not an ISBN-13',
      () async {
        var calls = 0;
        final catalog = catalogReturning((_) {
          calls++;
          return xml(fixture('bnf_no_record.xml'));
        });

        for (final text in [
          '',
          '123',
          '0451524934',
          '" or bib.title all "x',
          'https://x',
        ]) {
          expect(await catalog.fetchByIsbn(text), isNull, reason: text);
        }
        expect(calls, 0);
      },
    );
  });

  group('real records', () {
    test('One Piece T15: series and number are structured', () async {
      final catalog = catalogAnswering(fixture('bnf_one_piece_15.xml'));

      expect(
        await catalog.fetchByIsbn(_isbn),
        const BookMetadata(
          title: 'Droit devant !!',
          authors: ['Eiichirō Oda'],
          publisher: 'Glénat',
          publishedDate: '2013',
          seriesTitle: 'One piece',
          seriesNumber: 15,
        ),
      );
    });

    test(
      'a Dargaud album: publisher and year from the 214 of publication',
      () async {
        final catalog = catalogAnswering(fixture('bnf_fees_valentines_2.xml'));

        expect(
          await catalog.fetchByIsbn('9782205076745'),
          const BookMetadata(
            title: 'Une chaussure à son pied',
            authors: ['Crip'],
            publisher: 'Dargaud',
            publishedDate: '2018',
            seriesTitle: 'Les fées Valentines',
            seriesNumber: 2,
          ),
        );
      },
    );

    test('no record: null', () async {
      final catalog = catalogAnswering(fixture('bnf_no_record.xml'));

      expect(await catalog.fetchByIsbn('9780000000002'), isNull);
    });
  });

  group('parsing', () {
    Future<BookMetadata?> parse(String fields, {String isbn = _isbn}) =>
        catalogAnswering(sruWith(fields)).fetchByIsbn(isbn);

    test('reads the complement of the title as the subtitle', () async {
      final metadata = await parse(
        field('200', {'a': 'Naruto', 'e': 'Le rêve'}),
      );

      expect(metadata!.title, 'Naruto');
      expect(metadata.subtitle, 'Le rêve');
    });

    test('a title is required', () async {
      expect(await parse(field('225', {'a': 'One piece', 'v': '3'})), isNull);
      expect(await parse(field('200', {'b': 'Texte imprimé'})), isNull);
    });

    test('a part title takes the series from the same field', () async {
      final metadata = await parse(
        field('200', {'a': 'Blacksad', 'h': '7', 'i': 'Alors, tout tombe'}),
      );

      expect(metadata!.title, 'Alors, tout tombe');
      expect(metadata.seriesTitle, 'Blacksad');
      expect(metadata.seriesNumber, 7);
    });

    test('461 wins over 225 when both are numbered', () async {
      final metadata = await parse(
        field('200', {'a': 'Droit devant'}) +
            field('225', {'a': 'One piece (collection)', 'v': '99'}) +
            field('461', {'t': 'One piece', 'v': '15'}),
      );

      expect(metadata!.seriesTitle, 'One piece');
      expect(metadata.seriesNumber, 15);
    });

    test(
      'the name comes from the 461 even when only a 225 is numbered',
      () async {
        final metadata = await parse(
          field('200', {'a': 'Droit devant'}) +
              field('225', {'a': 'One Piece. Édition originale', 'v': '15'}) +
              field('461', {'t': 'One piece'}),
        );

        expect(metadata!.seriesTitle, 'One piece');
        expect(metadata.seriesNumber, 15);
      },
    );

    test('a copyright 214 is the last resort for the year', () async {
      final metadata = await parse(
        field('200', {'a': 'Titre'}) +
            field('214', {'d': 'cop. 2018'}, ind2: '4') +
            field('214', {'c': 'Impr. PPO', 'd': '2019'}, ind2: '3'),
      );

      expect(metadata!.publishedDate, '2018');
      expect(metadata.publisher, isNull);
    });

    test('225 is used without a 461', () async {
      final metadata = await parse(
        field('200', {'a': 'Droit devant'}) +
            field('225', {'a': 'One piece', 'v': 'T. 15'}),
      );

      expect(metadata!.seriesTitle, 'One piece');
      expect(metadata.seriesNumber, 15);
    });

    test('a publisher collection with an ISSN is not a series', () async {
      final metadata = await parse(
        field('200', {'a': 'Droit devant'}) +
            field('225', {'a': 'Shonen manga', 'x': '1761-2268', 'v': '4'}),
      );

      expect(metadata!.seriesTitle, isNull);
      expect(metadata.seriesNumber, isNull);
    });

    test('a numbered series wins over an earlier unnumbered one', () async {
      final metadata = await parse(
        field('200', {'a': 'Droit devant'}) +
            field('225', {'a': 'Grand format'}) +
            field('225', {'a': 'One piece', 'v': '15'}),
      );

      expect(metadata!.seriesTitle, 'One piece');
      expect(metadata.seriesNumber, 15);
    });

    test('a series without a usable number keeps its name', () async {
      for (final number in ['10.5', '3-4', 'hors-série', '']) {
        final metadata = await parse(
          field('200', {'a': 'Droit devant'}) +
              field('461', {'t': 'One piece', 'v': number}),
        );

        expect(metadata!.seriesTitle, 'One piece', reason: number);
        expect(metadata.seriesNumber, isNull, reason: number);
      }
    });

    test('roman numerals in the volume subfield are read', () async {
      final metadata = await parse(
        field('200', {'a': 'Le Pays des Mers'}) +
            field('461', {'t': 'Les Passagers du vent', 'v': 'II'}),
      );

      expect(metadata!.seriesNumber, 2);
    });

    test(
      'authors: 700, 701 and 702, without translators or prefacers',
      () async {
        final metadata = await parse(
          field('200', {'a': 'Titre'}) +
              field('700', {'a': 'Oda', 'b': 'Eiichirō', '4': '070'}) +
              field('701', {'a': 'Toriyama', 'b': 'Akira'}) +
              field('702', {'a': 'Rabahi', 'b': 'Djamel', '4': '730'}) +
              field('702', {'a': 'Préface', 'b': 'Une', '4': '080'}) +
              field('702', {'a': 'Crip', '4': '440'}) +
              field('702', {'a': 'Oda', 'b': 'Eiichirō', '4': '070'}),
        );

        expect(metadata!.authors, ['Eiichirō Oda', 'Akira Toriyama', 'Crip']);
      },
    );

    test('publisher and year: 214 of publication wins over printing', () async {
      final metadata = await parse(
        field('200', {'a': 'Titre'}) +
            field('214', {'c': 'Impr. PPO', 'd': '2019'}, ind2: '3') +
            field('214', {'c': 'Dargaud', 'd': 'DL 2018'}, ind2: '0'),
      );

      expect(metadata!.publisher, 'Dargaud');
      expect(metadata.publishedDate, '2018');
    });

    test('publisher and year: 210 is the fallback', () async {
      final metadata = await parse(
        field('200', {'a': 'Titre'}) +
            field('210', {'a': 'Paris', 'c': 'Dupuis', 'd': 'cop. 1998'}),
      );

      expect(metadata!.publisher, 'Dupuis');
      expect(metadata.publishedDate, '1998');
    });

    test('a record without publication data has none', () async {
      final metadata = await parse(field('200', {'a': 'Titre'}));

      expect(metadata!.publisher, isNull);
      expect(metadata.publishedDate, isNull);
      expect(metadata.authors, isEmpty);
      expect(metadata.imageUrl, isNull);
    });

    test('a year is four digits', () async {
      final metadata = await parse(
        field('200', {'a': 'Titre'}) + field('210', {'c': 'X', 'd': 's.d.'}),
      );

      expect(metadata!.publishedDate, isNull);
    });

    test('drops non-sorting control characters and extra spaces', () async {
      final metadata = await parse(
        field('200', {'a': '\u0088Le\u0089  Petit   Prince'}),
      );

      expect(metadata!.title, 'Le Petit Prince');
    });

    test('keeps the first value of a repeated subfield', () async {
      final metadata = await parse(
        '${field('200', {'a': 'Un titre'})}'
        '<mxc:datafield tag="214" ind1=" " ind2="0">'
        '<mxc:subfield code="a">Paris</mxc:subfield>'
        '<mxc:subfield code="c">Dargaud</mxc:subfield>'
        '<mxc:subfield code="c">Autre</mxc:subfield>'
        '</mxc:datafield>',
      );

      expect(metadata!.publisher, 'Dargaud');
    });

    group('ISBN of the record', () {
      test('010 in ISBN-13 with hyphens matches', () async {
        final metadata = await parse(
          field('010', {'a': '978-2-7234-9260-7'}) + field('200', {'a': 'T'}),
        );

        expect(metadata, isNotNull);
      });

      test('010 in ISBN-10 matches the ISBN-13', () async {
        final metadata = await parse(
          field('010', {'a': '2-7234-9260-5'}) + field('200', {'a': 'T'}),
        );

        expect(metadata, isNotNull);
      });

      test('073 matches too', () async {
        final metadata = await parse(
          field('073', {'a': _isbn}) + field('200', {'a': 'T'}),
        );

        expect(metadata, isNotNull);
      });

      test('the right record is found when it is not the first', () async {
        final catalog = catalogAnswering(
          sruWithRecords([
            field('010', {'a': '978-2-205-07674-5'}) +
                field('200', {'a': 'Mauvais livre'}),
            field('010', {'a': '978-2-7234-9260-7'}) +
                field('200', {'a': 'Bon livre'}),
          ]),
        );

        expect((await catalog.fetchByIsbn(_isbn))!.title, 'Bon livre');
      });

      test('only records of another ISBN: null', () async {
        final catalog = catalogAnswering(
          sruWithRecords([
            field('010', {'a': '978-2-205-07674-5'}) + field('200', {'a': 'A'}),
            field('010', {'a': '978-2-205-08533-4'}) + field('200', {'a': 'B'}),
          ]),
        );

        expect(await catalog.fetchByIsbn(_isbn), isNull);
      });

      test(
        'the erroneous ISBN printed on the book (010 \$z) matches too',
        () async {
          final metadata = await parse(
            field('010', {'a': '978-2-205-07674-5', 'z': '978-2-7234-9260-7'}) +
                field('200', {'a': 'T'}),
          );

          expect(metadata, isNotNull);
        },
      );

      test('a record of another ISBN is ignored', () async {
        final metadata = await parse(
          field('010', {'a': '978-2-205-07674-5'}) + field('200', {'a': 'T'}),
        );

        expect(metadata, isNull);
      });

      test('no ISBN in the record: accepted', () async {
        expect(await parse(field('200', {'a': 'T'})), isNotNull);
      });
    });
  });

  group('failures', () {
    Future<Object?> failureOf(BnfCatalog catalog) async {
      try {
        await catalog.fetchByIsbn(_isbn);
      } on BookFailure catch (failure) {
        return failure;
      }
      return null;
    }

    test('no network: network', () async {
      final catalog = BnfCatalog(
        httpClient: MockClient(
          (_) async => throw http.ClientException('Failed host lookup'),
        ),
      );

      expect(await failureOf(catalog), BookFailure.network);
    });

    test('a timeout: network', () async {
      final catalog = BnfCatalog(
        httpClient: MockClient((_) async => throw TimeoutException('slow')),
      );

      expect(await failureOf(catalog), BookFailure.network);
    });

    test('a TLS failure: unavailable', () async {
      final catalog = BnfCatalog(
        httpClient: MockClient(
          (_) async => throw const HandshakeException('bad certificate'),
        ),
      );

      expect(await failureOf(catalog), BookFailure.unavailable);
    });

    test('any HTTP error, 429 included: unavailable', () async {
      for (final status in [400, 404, 429, 500, 503]) {
        final catalog = catalogReturning((_) => http.Response('', status));

        expect(
          await failureOf(catalog),
          BookFailure.unavailable,
          reason: '$status',
        );
      }
    });

    test('a body that is not XML: unavailable', () async {
      expect(
        await failureOf(catalogAnswering('<html><body>oops')),
        BookFailure.unavailable,
      );
      expect(await failureOf(catalogAnswering('')), BookFailure.unavailable);
    });

    test('XML that is not an SRU response: unavailable', () async {
      expect(
        await failureOf(catalogAnswering('<html><body/></html>')),
        BookFailure.unavailable,
      );
    });

    test('decodes UTF-8 even when the response names no charset', () async {
      final catalog = catalogReturning(
        (_) => http.Response.bytes(
          utf8.encode(fixture('bnf_one_piece_15.xml')),
          200,
          headers: {'content-type': 'text/xml'},
        ),
      );

      final metadata = await catalog.fetchByIsbn(_isbn);

      expect(metadata!.publisher, 'Glénat');
      expect(metadata.authors, ['Eiichirō Oda']);
    });

    test('an SRU diagnostic next to records is not fatal', () async {
      final catalog = catalogAnswering(
        sruWithRecords(
          [
            field('200', {'a': 'Bon livre'}),
          ],
          diagnostics:
              '<srw:diagnostics><diag:diagnostic><diag:uri>x</diag:uri>'
              '</diag:diagnostic></srw:diagnostics>',
        ),
      );

      expect((await catalog.fetchByIsbn(_isbn))!.title, 'Bon livre');
    });

    test('an SRU diagnostic: unavailable', () async {
      const body = '''
<?xml version="1.0"?>
<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/" xmlns:diag="http://www.loc.gov/zing/srw/diagnostic/">
<srw:version>1.2</srw:version><srw:numberOfRecords>0</srw:numberOfRecords>
<srw:diagnostics><diag:diagnostic><diag:uri>info:srw/diagnostic/1/10</diag:uri></diag:diagnostic></srw:diagnostics>
</srw:searchRetrieveResponse>''';

      expect(await failureOf(catalogAnswering(body)), BookFailure.unavailable);
    });

    test('never reports a quota failure', () async {
      final catalog = catalogReturning((_) => http.Response('', 429));

      expect(await failureOf(catalog), isNot(BookFailure.quotaExceeded));
    });
  });

  test('the provider builds the catalog on the shared HTTP client', () async {
    var calls = 0;
    final container = ProviderContainer.test(
      overrides: [
        httpClientProvider.overrideWithValue(
          MockClient((_) async {
            calls++;
            return xml(fixture('bnf_no_record.xml'));
          }),
        ),
      ],
    );

    expect(await container.read(bnfCatalogProvider).fetchByIsbn(_isbn), isNull);
    expect(calls, 1);
  });
}
