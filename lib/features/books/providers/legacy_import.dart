import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Import des anciens livres (`books`) dans l'étagère, une fois par session,
/// **à l'ouverture d'un écran de Livres** (qui le regarde), jamais au
/// démarrage de l'app.
///
/// Lit sur le serveur les anciens livres pas encore importés et l'étagère,
/// planifie ([planLegacyImport]) et écrit par lots, chaque ancien document
/// marqué `importedAt` dans le lot de son tome : idempotent, et un tome
/// retiré ne revient pas. Hors ligne, il échoue (`ShelfFailure.offline`) et
/// réessaie à l'ouverture suivante : le provider est libéré avec l'écran.
final legacyImportProvider = FutureProvider.autoDispose<void>(
  _importLegacyBooks,
  // Pas de relance automatique : un import coupé entre deux lots, relancé
  // aussitôt, recréerait des séries ; il réessaie à l'ouverture suivante.
  retry: _never,
);

Duration? _never(int retryCount, Object error) => null;

Future<void> _importLegacyBooks(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  if (ref.read(_importedSessionsProvider).contains(uid)) return;
  final repository = ref.watch(bookshelfRepositoryProvider);

  final now = ref.read(clockProvider)();

  final books = await repository.fetchLegacyBooks(uid);
  if (books.isNotEmpty) {
    final shelf = await repository.fetchShelf(uid);
    final plan = planLegacyImport(
      books: books,
      series: shelf.series,
      ownedVolumeIds: {for (final volume in shelf.volumes) volume.id},
      now: now,
      newSeriesId: () => repository.newSeriesId(uid),
    );
    await repository.applyLegacyImport(uid, plan, importedAt: now);
  }
  if (!ref.mounted) return;
  ref.read(_importedSessionsProvider.notifier).add(uid);
}

/// Comptes déjà importés depuis le lancement de l'app : l'import ne repasse
/// pas à chaque ouverture d'écran (il serait sans effet, mais coûte des
/// lectures sur le serveur).
final _importedSessionsProvider =
    NotifierProvider<_ImportedSessions, Set<String>>(_ImportedSessions.new);

class _ImportedSessions extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String uid) => state = {...state, uid};
}
