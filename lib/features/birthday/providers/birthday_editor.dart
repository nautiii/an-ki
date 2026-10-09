import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Écritures sur les anniversaires (ViewModel des actions) et état de la
/// dernière : `AsyncLoading` pendant l'écriture, `AsyncError` si elle échoue,
/// sinon `AsyncData`.
///
/// Écritures optimistes : l'UI n'attend pas ces méthodes, car Firestore
/// applique l'écriture au cache local tout de suite (le flux d'anniversaires
/// se met à jour) et ne résout le Future qu'à l'accusé du serveur — jamais
/// hors ligne. L'écran d'accueil écoute ce provider pour signaler un échec.
class BirthdayEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> create(BirthdayDraft draft) => _write(
    (uid) => ref.read(birthdayRepositoryProvider).createBirthday(uid, draft),
  );

  Future<void> edit(String birthdayId, BirthdayDraft draft) => _write(
    (uid) => ref
        .read(birthdayRepositoryProvider)
        .updateBirthday(uid, birthdayId, draft),
  );

  Future<void> delete(String birthdayId) => _write(
    (_) => ref.read(birthdayRepositoryProvider).deleteBirthday(birthdayId),
  );

  /// Exécute une écriture pour l'utilisateur courant et publie son issue.
  /// Hors session, ne fait rien (comme l'UI avant elle).
  Future<void> _write(Future<void> Function(String uid) write) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => write(uid));
    // Le provider a pu être libéré pendant l'attente (écran fermé).
    if (ref.mounted) state = result;
  }
}

final birthdayEditorProvider =
    AsyncNotifierProvider.autoDispose<BirthdayEditor, void>(BirthdayEditor.new);
