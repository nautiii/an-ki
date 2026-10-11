import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:an_ki/features/book_scanner/providers/isbn_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _book = Book(
  id: '',
  isbn: '987654321',
  title: '1984',
  authors: ['George Orwell'],
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
      RecordingBookRepository(throwOnScan: BookFailure.quotaExceeded),
    );

    await expectLater(
      container.read(isbnLookupProvider.notifier).lookUp('1'),
      throwsA(BookFailure.quotaExceeded),
    );
    expect(container.read(isbnLookupProvider).hasError, isTrue);
  });
}
