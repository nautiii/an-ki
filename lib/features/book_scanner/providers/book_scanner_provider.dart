import 'dart:async';
import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookScannerState {
  final List<BookModel> savedBooks;
  final BookModel? scannedBook;
  final bool isLoading;
  final bool isScanning;
  final bool isSaving;
  final Object? error;

  BookScannerState({
    this.savedBooks = const [],
    this.scannedBook,
    this.isLoading = false,
    this.isScanning = false,
    this.isSaving = false,
    this.error,
  });

  BookScannerState copyWith({
    List<BookModel>? savedBooks,
    BookModel? scannedBook,
    bool? isLoading,
    bool? isScanning,
    bool? isSaving,
    Object? error,
    bool clearScannedBook = false,
    bool clearError = false,
  }) {
    return BookScannerState(
      savedBooks: savedBooks ?? this.savedBooks,
      scannedBook: clearScannedBook ? null : (scannedBook ?? this.scannedBook),
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BookScannerNotifier extends Notifier<BookScannerState> {
  @override
  BookScannerState build() {
    ref.onDispose(() => _subscription?.cancel());
    return BookScannerState();
  }

  BookRepository get _repository => ref.watch(bookRepositoryProvider);
  StreamSubscription<List<BookModel>>? _subscription;

  void startListening(String uid) {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true);

    _subscription = _repository
        .watchBooks(uid)
        .listen(
          (books) {
            if (ref.mounted) {
              state = state.copyWith(savedBooks: books, isLoading: false);
            }
          },
          onError: (err) {
            if (ref.mounted) {
              state = state.copyWith(isLoading: false, error: err);
            }
          },
        );
  }

  Future<BookModel?> scanIsbn(String isbn) async {
    state = state.copyWith(
      isScanning: true,
      clearError: true,
      clearScannedBook: true,
    );

    try {
      final book = await _repository.fetchBookByIsbn(isbn);
      if (ref.mounted) {
        state = state.copyWith(scannedBook: book, isScanning: false);
      }
      return book;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isScanning: false, error: e);
      }
      rethrow;
    }
  }

  Future<void> saveBook(BookModel book) async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) return;

    state = state.copyWith(isSaving: true);
    try {
      await _repository.saveBook(uid, book);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  Future<void> deleteBook(String bookId) async {
    await _repository.deleteBook(bookId);
  }

  void reset() {
    state = state.copyWith(clearScannedBook: true, clearError: true);
  }
}

final bookScannerProvider =
    NotifierProvider<BookScannerNotifier, BookScannerState>(
      BookScannerNotifier.new,
    );

final savedBooksProvider = Provider<List<BookModel>>((ref) {
  return ref.watch(bookScannerProvider.select((s) => s.savedBooks));
});
