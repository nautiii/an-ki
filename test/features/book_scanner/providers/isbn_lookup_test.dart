import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/isbn_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

final _book = BookModel(
  id: '',
  uid: '',
  isbn: '987654321',
  title: '1984',
  authors: const ['George Orwell'],
);

void main() {
  ProviderContainer makeContainer(RecordingBookRepository repo) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(isbnLookupProvider, (_, _) {});
    return container;
  }

  test('returns and publishes the book found', () async {
    final container = makeContainer(RecordingBookRepository(bookByIsbn: _book));
    final lookup = container.read(isbnLookupProvider.notifier);

    final future = lookup.lookUp('987654321');
    expect(container.read(isbnLookupProvider).isLoading, isTrue);

    expect(await future, _book);
    expect(container.read(isbnLookupProvider).value, _book);
  });

  test('returns null for an unknown ISBN', () async {
    final container = makeContainer(RecordingBookRepository());

    expect(await container.read(isbnLookupProvider.notifier).lookUp('0'), null);
    expect(container.read(isbnLookupProvider).hasValue, isTrue);
  });

  test('rethrows and publishes the error', () async {
    final container = makeContainer(
      RecordingBookRepository(throwOnScan: GoogleBooksQuotaExceededException()),
    );

    await expectLater(
      container.read(isbnLookupProvider.notifier).lookUp('1'),
      throwsA(isA<GoogleBooksQuotaExceededException>()),
    );
    expect(container.read(isbnLookupProvider).hasError, isTrue);
  });
}
