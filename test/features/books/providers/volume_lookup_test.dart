import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _isbn = '9782344059562';

/// Catalogue qui répond [metadata] ou lève [failure].
class _Bnf extends Fake implements BnfCatalog {
  _Bnf({this.metadata, this.failure});

  final BookMetadata? metadata;
  final BookFailure? failure;

  @override
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    if (failure case final error?) throw error;
    return metadata;
  }
}

class _Google extends Fake implements GoogleBooksCatalog {
  _Google({this.metadata, this.failure});

  final BookMetadata? metadata;
  final BookFailure? failure;

  @override
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    if (failure case final error?) throw error;
    return metadata;
  }
}

const _bnfRecord = BookMetadata(
  title: 'One Piece',
  authors: ['Eiichirō Oda'],
  seriesTitle: 'One Piece',
  seriesNumber: 108,
);
const _googleRecord = BookMetadata(
  title: 'One Piece - Tome 108',
  authors: [],
  imageUrl: 'https://img/108.jpg',
);

void main() {
  VolumeLookup lookupWith({
    required BnfCatalog bnf,
    required GoogleBooksCatalog google,
  }) {
    final container = ProviderContainer.test(
      overrides: [
        bnfCatalogProvider.overrideWithValue(bnf),
        googleBooksCatalogProvider.overrideWithValue(google),
      ],
    );
    return container.read(volumeLookupProvider);
  }

  test('merges both catalogues, the BnF first', () async {
    final found = await lookupWith(
      bnf: _Bnf(metadata: _bnfRecord),
      google: _Google(metadata: _googleRecord),
    ).lookUp(_isbn);

    expect(found?.isbn, _isbn);
    expect(found?.metadata.imageUrl, 'https://img/108.jpg');
    expect(found?.guess?.number, 108);
  });

  test('one source failing is ignored when the other knows the book', () async {
    final fromGoogle = await lookupWith(
      bnf: _Bnf(failure: BookFailure.unavailable),
      google: _Google(metadata: _googleRecord),
    ).lookUp(_isbn);
    final fromBnf = await lookupWith(
      bnf: _Bnf(metadata: _bnfRecord),
      google: _Google(failure: BookFailure.quotaExceeded),
    ).lookUp(_isbn);

    expect(fromGoogle?.metadata.title, 'One Piece - Tome 108');
    expect(fromBnf?.guess?.seriesName, 'One Piece');
  });

  test('unknown to both: null', () async {
    expect(
      await lookupWith(bnf: _Bnf(), google: _Google()).lookUp(_isbn),
      isNull,
    );
  });

  test('a failure without an answer is raised, the network first', () async {
    Future<Object?> failureOf(BookFailure? bnf, BookFailure? google) async {
      try {
        await lookupWith(
          bnf: _Bnf(failure: bnf),
          google: _Google(failure: google),
        ).lookUp(_isbn);
        return null;
      } on BookFailure catch (failure) {
        return failure;
      }
    }

    // Inconnu de l'une, l'autre injoignable : pas « introuvable ».
    expect(
      await failureOf(null, BookFailure.quotaExceeded),
      BookFailure.quotaExceeded,
    );
    expect(await failureOf(BookFailure.network, null), BookFailure.network);
    expect(
      await failureOf(BookFailure.unavailable, BookFailure.network),
      BookFailure.network,
    );
    expect(
      await failureOf(BookFailure.unavailable, BookFailure.quotaExceeded),
      BookFailure.quotaExceeded,
    );
    expect(
      await failureOf(BookFailure.unavailable, BookFailure.unavailable),
      BookFailure.unavailable,
    );
  });
}
