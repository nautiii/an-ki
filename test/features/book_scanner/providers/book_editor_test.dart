import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/book_editor.dart';
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
  ProviderContainer makeContainer(
    RecordingBookRepository repo, {
    String? uid = 'u1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container.listen(bookEditorProvider, (_, _) {});
    return container;
  }

  test('saves the book for the signed-in user', () async {
    final repo = RecordingBookRepository();
    final container = makeContainer(repo);

    await container.read(bookEditorProvider.notifier).save(_book);

    expect(repo.saved, [_book]);
    expect(container.read(bookEditorProvider), isA<AsyncData<void>>());
  });

  test('does nothing without a session', () async {
    final repo = RecordingBookRepository();
    final container = makeContainer(repo, uid: null);

    await container.read(bookEditorProvider.notifier).save(_book);

    expect(repo.saved, isEmpty);
  });

  test('publishes a failed save as an AsyncError', () async {
    final container = makeContainer(
      RecordingBookRepository(failure: Exception('denied')),
    );

    await container.read(bookEditorProvider.notifier).save(_book);

    expect(container.read(bookEditorProvider).hasError, isTrue);
  });
}
