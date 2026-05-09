import 'dart:async';
import 'package:an_ki/features/book_scanner/models/book_model.dart';
import 'package:an_ki/features/book_scanner/repositories/book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookScannerNotifier extends AsyncNotifier<BookModel?> {
  @override
  FutureOr<BookModel?> build() {
    return null;
  }

  Future<void> scanIsbn(String isbn) async {
    state = const AsyncValue.loading();
    final repository = ref.read(bookRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      return await repository.fetchBookByIsbn(isbn);
    });

    if (ref.mounted) {
      state = result;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final bookScannerProvider =
    AsyncNotifierProvider<BookScannerNotifier, BookModel?>(
      BookScannerNotifier.new,
    );
