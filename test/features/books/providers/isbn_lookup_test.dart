import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/isbn_lookup.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

IdentifiedVolume _orwell(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: '1984', authors: ['George Orwell']),
);

void main() {
  ProviderContainer makeContainer(RecordingVolumeLookup lookup) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [volumeLookupProvider.overrideWithValue(lookup)],
    );
    container.listen(isbnLookupProvider, (_, _) {});
    return container;
  }

  test('returns and publishes the book found', () async {
    final container = makeContainer(RecordingVolumeLookup(found: _orwell));
    final lookup = container.read(isbnLookupProvider.notifier);

    final future = lookup.lookUp('9780451524935');
    expect(container.read(isbnLookupProvider).isLoading, isTrue);

    expect(await future, _orwell('9780451524935'));
    expect(container.read(isbnLookupProvider).value, _orwell('9780451524935'));
  });

  test('returns null for an unknown ISBN', () async {
    final container = makeContainer(RecordingVolumeLookup());

    expect(await container.read(isbnLookupProvider.notifier).lookUp('0'), null);
    expect(container.read(isbnLookupProvider).hasValue, isTrue);
  });

  test('rethrows and publishes the error', () async {
    final container = makeContainer(
      RecordingVolumeLookup(failure: BookFailure.quotaExceeded),
    );

    await expectLater(
      container.read(isbnLookupProvider.notifier).lookUp('1'),
      throwsA(BookFailure.quotaExceeded),
    );
    expect(container.read(isbnLookupProvider).hasError, isTrue);
  });
}
