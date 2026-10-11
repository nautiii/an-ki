import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Livres scannés par l'utilisateur courant, en temps réel ; liste vide hors
/// session.
///
/// Dérivé de [currentUidProvider] : l'abonnement suit la session sans code
/// d'initialisation ni remise à zéro manuelle.
final savedBooksProvider = StreamProvider<List<Book>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookRepositoryProvider).watchBooks(uid);
});
