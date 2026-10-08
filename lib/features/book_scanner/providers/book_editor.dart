import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ajout d'un livre à la liste de l'utilisateur (ViewModel de l'action) et
/// état de la dernière écriture : `AsyncLoading`, puis `AsyncData` ou
/// `AsyncError`.
///
/// Écriture optimiste : l'UI n'attend pas (Firestore applique l'écriture au
/// cache local et le flux des livres se met à jour) ; l'écran du scanner écoute
/// ce provider pour signaler un échec.
class BookEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Ajoute [book] à la liste de l'utilisateur courant, daté de maintenant ;
  /// hors session, ne fait rien.
  Future<void> save(BookModel book) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final repository = ref.read(bookRepositoryProvider);
    final now = ref.read(clockProvider)();
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => repository.saveBook(uid, book, scannedAt: now),
    );
    if (ref.mounted) state = result;
  }
}

final bookEditorProvider = AsyncNotifierProvider.autoDispose<BookEditor, void>(
  BookEditor.new,
);
