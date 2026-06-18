import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

/// A configurable [BookRepository] double for the real notifier.
class ConfigurableBookRepository extends FakeBookRepository {
  ConfigurableBookRepository({this.bookByIsbn, this.throwOnScan});

  final BookModel? bookByIsbn;
  final Object? throwOnScan;
  final List<BookModel> saved = [];

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    if (throwOnScan != null) throw throwOnScan!;
    return bookByIsbn;
  }

  @override
  Future<void> saveBook(String uid, BookModel book) async => saved.add(book);

  final List<String> deleted = [];
  @override
  Future<void> deleteBook(String bookId) async => deleted.add(bookId);
}

class _ErroringBookRepository extends FakeBookRepository {
  @override
  Stream<List<BookModel>> watchBooks(String uid) =>
      Stream.error(Exception('stream failed'));
}

BookModel _book({String id = '1', String? imageUrl}) => BookModel(
  id: id,
  uid: 'fake-uid',
  isbn: '987654321',
  title: '1984',
  authors: const ['George Orwell'],
  description: 'Big Brother is watching you.',
  imageUrl: imageUrl,
);

void main() {
  group('BookScannerScreen rendering', () {
    testWidgets('shows the title and empty state', (tester) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookScannerProvider.overrideWith(
            () => FakeBookScannerNotifier(initialState: BookScannerState()),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Scanner de livres'), findsOneWidget);
      expect(find.text('Aucun livre trouvé.'), findsOneWidget);
    });

    testWidgets('shows a loading indicator while loading', (tester) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookScannerProvider.overrideWith(
            () => FakeBookScannerNotifier(
              initialState: BookScannerState(isLoading: true),
            ),
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('displays saved books in a carousel', (tester) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookScannerProvider.overrideWith(
            () => FakeBookScannerNotifier(
              initialState: BookScannerState(savedBooks: [_book()]),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1984'), findsOneWidget);
    });
  });

  group('BookScannerScreen scan flow (real notifier + fake camera)', () {
    late FakeMobileScannerPlatform platform;

    setUp(() => platform = FakeMobileScannerPlatform.install());

    void detect(WidgetTester tester, String isbn) {
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: isbn)]));
    }

    testWidgets('a successful scan opens the sheet and saves the book', (
      tester,
    ) async {
      final repo = ConfigurableBookRepository(bookByIsbn: _book());

      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
          ),
        ],
      );
      await tester.pump();

      detect(tester, '987654321');
      // Cannot pumpAndSettle: the scanner keeps an animated processing overlay.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(BookInfoSheet), findsOneWidget);
      expect(platform.stopCalls, greaterThan(0));

      await tester.tap(find.text('Ajouter'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.title, '1984');
      expect(find.byType(BookInfoSheet), findsNothing);
    });

    testWidgets('an unknown ISBN shows the "not found" message', (
      tester,
    ) async {
      final repo = ConfigurableBookRepository();

      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [bookRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pump();

      detect(tester, '000');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Livre non trouvé'), findsOneWidget);
      // Drain the SnackBar auto-dismiss timer + camera restart.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a generic error shows the "not found" message', (
      tester,
    ) async {
      final repo = ConfigurableBookRepository(throwOnScan: Exception('boom'));

      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [bookRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pump();

      detect(tester, '111');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Livre non trouvé'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a quota error shows the dedicated message', (tester) async {
      final repo = ConfigurableBookRepository(
        throwOnScan: GoogleBooksQuotaExceededException(),
      );

      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [bookRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pump();

      detect(tester, '123');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.text(
          'Limite de recherche atteinte. Veuillez réessayer plus tard.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('BookScannerNotifier', () {
    ProviderContainer makeContainer({
      BookRepository? repository,
      AuthState? authState,
    }) {
      final container = ProviderContainer(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            repository ?? FakeBookRepository(),
          ),
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: authState ?? AuthState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initial state is empty', () {
      final container = makeContainer();
      final state = container.read(bookScannerProvider);

      expect(state.isLoading, false);
      expect(state.savedBooks, isEmpty);
      expect(state.scannedBook, isNull);
    });

    test('scanIsbn updates the state with the fetched book', () async {
      final book = _book();
      final container = makeContainer(
        repository: ConfigurableBookRepository(bookByIsbn: book),
      );
      final notifier = container.read(bookScannerProvider.notifier);

      final future = notifier.scanIsbn('987654321');
      expect(container.read(bookScannerProvider).isScanning, true);

      final result = await future;
      expect(result, book);
      expect(container.read(bookScannerProvider).isScanning, false);
      expect(container.read(bookScannerProvider).scannedBook, book);
    });

    test('scanIsbn rethrows and records the error', () async {
      final container = makeContainer(
        repository: ConfigurableBookRepository(
          throwOnScan: GoogleBooksQuotaExceededException(),
        ),
      );
      final notifier = container.read(bookScannerProvider.notifier);

      await expectLater(
        notifier.scanIsbn('1'),
        throwsA(isA<GoogleBooksQuotaExceededException>()),
      );
      expect(container.read(bookScannerProvider).isScanning, false);
      expect(container.read(bookScannerProvider).error, isNotNull);
    });

    test('saveBook persists the book when a user is signed in', () async {
      final repo = ConfigurableBookRepository();
      final container = makeContainer(
        repository: repo,
        authState: AuthState(user: MockUser()),
      );

      await container.read(bookScannerProvider.notifier).saveBook(_book());

      expect(repo.saved, hasLength(1));
    });

    test('saveBook is a no-op when no user is signed in', () async {
      final repo = ConfigurableBookRepository();
      final container = makeContainer(repository: repo);

      await container.read(bookScannerProvider.notifier).saveBook(_book());

      expect(repo.saved, isEmpty);
    });

    test('reset clears the scanned book and error', () {
      final container = makeContainer();
      final notifier = container.read(bookScannerProvider.notifier);

      notifier.reset();

      expect(container.read(bookScannerProvider).scannedBook, isNull);
      expect(container.read(bookScannerProvider).error, isNull);
    });

    test('startListening streams saved books from the repository', () async {
      final container = makeContainer(
        repository: _StreamingBookRepository([_book()]),
      );
      container.read(bookScannerProvider.notifier).startListening('fake-uid');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(bookScannerProvider).savedBooks, hasLength(1));
      expect(container.read(bookScannerProvider).isLoading, false);
    });

    test('startListening records stream errors', () async {
      final container = makeContainer(repository: _ErroringBookRepository());
      container.read(bookScannerProvider.notifier).startListening('fake-uid');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(bookScannerProvider).isLoading, false);
      expect(container.read(bookScannerProvider).error, isNotNull);
    });

    test('deleteBook forwards to the repository', () async {
      final repo = ConfigurableBookRepository();
      final container = makeContainer(repository: repo);

      await container.read(bookScannerProvider.notifier).deleteBook('book-1');

      expect(repo.deleted, ['book-1']);
    });

    test('savedBooksProvider exposes the saved books', () {
      final container = ProviderContainer(
        overrides: [
          bookScannerProvider.overrideWith(
            () => FakeBookScannerNotifier(
              initialState: BookScannerState(savedBooks: [_book()]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(savedBooksProvider), hasLength(1));
    });
  });
}

class _StreamingBookRepository extends FakeBookRepository {
  _StreamingBookRepository(this.books);
  final List<BookModel> books;

  @override
  Stream<List<BookModel>> watchBooks(String uid) => Stream.value(books);
}
