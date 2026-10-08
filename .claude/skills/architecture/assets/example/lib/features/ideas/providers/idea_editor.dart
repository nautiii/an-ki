import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/ideas/data/idea_repository.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions sur les idées (ViewModel des écritures) et état de la dernière :
/// `AsyncLoading` pendant l'écriture, `AsyncError` ([IdeaFailure]) si elle
/// échoue, sinon `AsyncData`.
///
/// Écritures optimistes : l'UI n'attend pas ces méthodes, car Firestore
/// applique l'écriture au cache local tout de suite et le flux d'idées se met
/// à jour. L'écran hôte écoute ce provider pour signaler un échec tardif.
class IdeaEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> add(IdeaDraft draft) => _write((uid) {
    if (!draft.isValid) throw IdeaFailure.invalidDraft;
    final now = ref.read(clockProvider)();
    return ref.read(ideaRepositoryProvider).addIdea(uid, draft, now: now);
  });

  Future<void> delete(String ideaId) =>
      _write((uid) => ref.read(ideaRepositoryProvider).deleteIdea(uid, ideaId));

  /// Exécute une écriture pour l'utilisateur courant et publie son issue.
  Future<void> _write(Future<Object?> Function(String uid) write) async {
    final uid = ref.read(currentUidProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      if (uid == null) throw IdeaFailure.signedOut;
      await write(uid);
    });
    // Le provider a pu être libéré pendant l'attente (écran fermé).
    if (ref.mounted) state = result;
  }
}

final ideaEditorProvider = AsyncNotifierProvider.autoDispose<IdeaEditor, void>(
  IdeaEditor.new,
);
