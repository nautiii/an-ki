import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

BookMetadata metadata({
  String title = 'Droit devant !!',
  String? subtitle,
  List<String> authors = const [],
  String? publisher,
  String? publishedDate,
  String? imageUrl,
  String? seriesTitle,
  int? seriesNumber,
}) => BookMetadata(
  title: title,
  subtitle: subtitle,
  authors: authors,
  publisher: publisher,
  publishedDate: publishedDate,
  imageUrl: imageUrl,
  seriesTitle: seriesTitle,
  seriesNumber: seriesNumber,
);

void main() {
  group('mergeMetadata', () {
    test('is null when no catalogue knows the book', () {
      expect(mergeMetadata(null, null), isNull);
    });

    test('keeps the only answer as it is', () {
      final bnf = metadata(seriesTitle: 'One piece', seriesNumber: 15);
      final google = metadata(title: 'One Piece T15');

      expect(mergeMetadata(bnf, null), bnf);
      expect(mergeMetadata(null, google), google);
    });

    test('series, number, title and publisher come from the BnF', () {
      final merged = mergeMetadata(
        metadata(
          publisher: 'Glénat',
          seriesTitle: 'One piece',
          seriesNumber: 15,
        ),
        metadata(
          title: 'One Piece - Tome 15',
          publisher: 'GLENAT',
          seriesTitle: 'One Piece (Google)',
          seriesNumber: 16,
        ),
      )!;

      expect(merged.title, 'Droit devant !!');
      expect(merged.publisher, 'Glénat');
      expect(merged.seriesTitle, 'One piece');
      expect(merged.seriesNumber, 15);
    });

    test('the cover comes from Google', () {
      final merged = mergeMetadata(
        metadata(imageUrl: 'https://bnf/cover.jpg'),
        metadata(imageUrl: 'https://books.google.com/cover.jpg'),
      )!;

      expect(merged.imageUrl, 'https://books.google.com/cover.jpg');
    });

    test('missing fields are filled from Google', () {
      final merged = mergeMetadata(
        metadata(title: ''),
        metadata(
          title: 'One Piece - Tome 15',
          subtitle: 'Droit devant',
          authors: const ['Eiichiro Oda'],
          publisher: 'Glénat',
          publishedDate: '2013-06-28',
          imageUrl: 'https://books.google.com/cover.jpg',
        ),
      )!;

      expect(merged.title, 'One Piece - Tome 15');
      expect(merged.subtitle, 'Droit devant');
      expect(merged.authors, ['Eiichiro Oda']);
      expect(merged.publisher, 'Glénat');
      expect(merged.publishedDate, '2013-06-28');
    });

    test('a Google subtitle only completes the same title', () {
      final merged = mergeMetadata(
        metadata(title: 'Le secret de la Licorne'),
        metadata(
          title: 'Les Aventures de Tintin',
          subtitle: 'Tome 11 : Le secret de la Licorne',
        ),
      )!;

      expect(merged.title, 'Le secret de la Licorne');
      expect(merged.subtitle, isNull);
    });

    test('the Google subtitle of the same title is kept', () {
      final merged = mergeMetadata(
        metadata(title: 'Blacksad'),
        metadata(title: 'BLACKSAD', subtitle: 'Tome 7'),
      )!;

      expect(merged.subtitle, 'Tome 7');
    });

    test('the BnF subtitle wins', () {
      final merged = mergeMetadata(
        metadata(title: 'Blacksad', subtitle: 'Alors, tout tombe'),
        metadata(title: 'Blacksad', subtitle: 'Tome 7'),
      )!;

      expect(merged.subtitle, 'Alors, tout tombe');
    });

    test('BnF authors win when present', () {
      final merged = mergeMetadata(
        metadata(authors: const ['Eiichirō Oda']),
        metadata(authors: const ['Eiichiro Oda', 'Someone Else']),
      )!;

      expect(merged.authors, ['Eiichirō Oda']);
    });

    test('series falls back to Google as a pair', () {
      final merged = mergeMetadata(
        metadata(),
        metadata(seriesTitle: 'One Piece', seriesNumber: 15),
      )!;

      expect(merged.seriesTitle, 'One Piece');
      expect(merged.seriesNumber, 15);
    });

    test('never mixes the BnF series name with the Google number', () {
      final merged = mergeMetadata(
        metadata(seriesTitle: 'Gaston'),
        metadata(seriesTitle: 'Gaston (Google)', seriesNumber: 3),
      )!;

      expect(merged.seriesTitle, 'Gaston');
      expect(merged.seriesNumber, isNull);
    });

    group('published date', () {
      test('the BnF year is refined by a Google date of the same year', () {
        expect(
          mergeMetadata(
            metadata(publishedDate: '2013'),
            metadata(publishedDate: '2013-06-28'),
          )!.publishedDate,
          '2013-06-28',
        );
        expect(
          mergeMetadata(
            metadata(publishedDate: '2013'),
            metadata(publishedDate: '2013-06'),
          )!.publishedDate,
          '2013-06',
        );
      });

      test('the BnF date stays when Google disagrees on the year', () {
        expect(
          mergeMetadata(
            metadata(publishedDate: '2013'),
            metadata(publishedDate: '2019-06-28'),
          )!.publishedDate,
          '2013',
        );
      });

      test('the BnF date stays when it is as precise as Google', () {
        expect(
          mergeMetadata(
            metadata(publishedDate: '2013-06-28'),
            metadata(publishedDate: '2013'),
          )!.publishedDate,
          '2013-06-28',
        );
      });

      test('Google fills a missing BnF date', () {
        expect(
          mergeMetadata(
            metadata(),
            metadata(publishedDate: '2013'),
          )!.publishedDate,
          '2013',
        );
      });
    });
  });

  test('metadata compares by value', () {
    final a = metadata(authors: const ['A'], seriesNumber: 1);
    final b = metadata(authors: const ['A'], seriesNumber: 1);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(metadata(authors: const ['B'], seriesNumber: 1)));
    expect(a, isNot(metadata(authors: const ['A'], seriesNumber: 2)));
  });
}
