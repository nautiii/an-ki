import 'dart:async';

import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Import des anniversaires du répertoire du téléphone.
///
/// État : `null` avant tout import, puis le nombre de contacts importés ;
/// `AsyncLoading` pendant l'import (un second appel est ignoré),
/// `AsyncError` si la permission est refusée ou la lecture échoue.
///
/// La partie locale (permission, lecture des contacts) est attendue ; les
/// écritures partent en lots sans attendre le serveur, pour rester instantanées
/// hors ligne.
class ContactImport extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<void> run() async {
    if (state.isLoading) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final contacts = ref.read(contactsServiceProvider);
    final repository = ref.read(birthdayRepositoryProvider);

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      if (!await contacts.requestReadPermission()) {
        throw Exception('Contacts permission denied');
      }
      final imported = await contacts.fetchBirthdays();
      unawaited(
        repository
            .createBirthdays(uid, [
              for (final contact in imported)
                BirthdayDraft(
                  name: contact.name,
                  surname: contact.surname,
                  date: contact.date,
                ),
            ])
            .catchError((Object error) {
              // Refus du serveur (règles) : un bug, pas une action utilisateur.
              debugPrint('[ContactImport] batch rejected: $error');
            }),
      );
      return imported.length;
    });
    if (ref.mounted) state = result;
  }
}

final contactImportProvider =
    AsyncNotifierProvider.autoDispose<ContactImport, int?>(ContactImport.new);
