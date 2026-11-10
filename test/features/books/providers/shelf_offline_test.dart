import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// Dépôt dont le flux « depuis le cache » est piloté par le test.
// Fermé par chaque test (addTearDown).
class _CacheFeed extends FakeBookshelfRepository {
  // ignore: close_sinks
  final feed = StreamController<bool>();

  @override
  Stream<bool> watchFromCache(String uid) => feed.stream;
}

void main() {
  const grace = ShelfOffline.grace;

  ProviderContainer makeContainer(
    BookshelfRepository repository, {
    String? uid = 'u1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container.listen(shelfOfflineProvider, (_, _) {});
    return container;
  }

  testWidgets('is false at start', (tester) async {
    final container = makeContainer(RecordingBookshelfRepository());
    await tester.pump();

    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('stays false before the grace period of cache-only answers', (
    tester,
  ) async {
    final repository = RecordingBookshelfRepository()..offline = true;
    final container = makeContainer(repository);
    await tester.pump();

    await tester.pump(grace - const Duration(milliseconds: 100));

    expect(container.read(shelfOfflineProvider), isFalse);
    // Libère le minuteur de grâce avant la fin du test.
    container.dispose();
  });

  testWidgets('turns true after the grace period, false when back online', (
    tester,
  ) async {
    final repository = RecordingBookshelfRepository()..offline = true;
    final container = makeContainer(repository);
    await tester.pump();

    await tester.pump(grace + const Duration(milliseconds: 100));
    expect(container.read(shelfOfflineProvider), isTrue);

    repository.offline = false;
    await tester.pump();
    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('a server answer within the grace period cancels the wait', (
    tester,
  ) async {
    final repository = RecordingBookshelfRepository()..offline = true;
    final container = makeContainer(repository);
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    repository.offline = false;
    await tester.pump(grace * 2);

    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('a failing stream is not offline', (tester) async {
    final repository = _CacheFeed();
    addTearDown(repository.feed.close);
    final container = makeContainer(repository);
    await tester.pump();

    repository.feed.add(true);
    await tester.pump(grace + const Duration(milliseconds: 100));
    expect(container.read(shelfOfflineProvider), isTrue);

    repository.feed.addError(Exception('boom'));
    await tester.pump();
    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('a failure during the grace period cancels the wait', (
    tester,
  ) async {
    final repository = _CacheFeed();
    addTearDown(repository.feed.close);
    final container = makeContainer(repository);
    await tester.pump();

    repository.feed.add(true);
    await tester.pump(const Duration(seconds: 1));
    repository.feed.addError(Exception('boom'));
    await tester.pump(grace * 2);

    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('a session change during the grace period cancels it', (
    tester,
  ) async {
    final repository = RecordingBookshelfRepository()..offline = true;
    final uid = NotifierProvider<_Uid, String?>(_Uid.new);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWith((ref) => ref.watch(uid)),
      ],
    );
    container.listen(shelfOfflineProvider, (_, _) {});
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    container.read(uid.notifier).change(null);
    await tester.pump(grace * 2);

    expect(container.read(shelfOfflineProvider), isFalse);
  });

  testWidgets('signed out, it is false', (tester) async {
    final repository = RecordingBookshelfRepository()..offline = true;
    final container = makeContainer(repository, uid: null);
    await tester.pump();

    await tester.pump(grace * 2);

    expect(container.read(shelfOfflineProvider), isFalse);
  });
}

class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void change(String? uid) => state = uid;
}
