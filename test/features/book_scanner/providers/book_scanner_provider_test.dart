import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book_model.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _book = BookModel(
  id: '1',
  isbn: '987654321',
  title: '1984',
  authors: ['George Orwell'],
);

class _ErroringBookRepository extends FakeBookRepository {
  @override
  Stream<List<BookModel>> watchBooks(String uid) =>
      Stream.error(Exception('stream failed'));
}

void main() {
  ProviderContainer makeContainer(FakeBookRepository repo, {String? uid}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Riverpod 3 met en pause un StreamProvider sans listener.
    container.listen(savedBooksProvider, (_, _) {});
    return container;
  }

  test('streams the books of the signed-in user', () async {
    final repo = RecordingBookRepository(books: [_book]);
    final container = makeContainer(repo, uid: 'u1');

    expect(await container.read(savedBooksProvider.future), [_book]);
    expect(repo.watchedUids, ['u1']);
  });

  test('is empty without a session', () async {
    final repo = RecordingBookRepository(books: [_book]);
    final container = makeContainer(repo);

    expect(await container.read(savedBooksProvider.future), isEmpty);
    expect(repo.watchedUids, isEmpty);
  });

  test('exposes stream errors', () async {
    final container = makeContainer(_ErroringBookRepository(), uid: 'u1');

    await Future<void>.delayed(Duration.zero);

    expect(container.read(savedBooksProvider).hasError, isTrue);
  });
}
