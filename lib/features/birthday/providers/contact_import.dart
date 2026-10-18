import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/features/birthday/domain/contact_import_preview.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lecture du répertoire pour l'import, et ajout des contacts choisis.
///
/// État : null avant [load], `AsyncLoading` pendant l'accès et la lecture,
/// puis les anniversaires lus ; `AsyncError` portant un
/// [ContactImportFailure] quand l'accès manque ou que la lecture échoue. Vit
/// le temps de l'écran d'import ; l'aperçu en dérive
/// ([contactImportPreviewProvider]).
class ContactImport extends AsyncNotifier<List<BirthdayDraft>?> {
  @override
  FutureOr<List<BirthdayDraft>?> build() => null;

  /// Demande l'accès (la boîte système quand elle peut encore s'afficher)
  /// et lit le répertoire. Un appel pendant la lecture est ignoré.
  Future<void> load() async {
    if (state.isLoading) return;
    final contacts = ref.read(contactsServiceProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      switch (await _guard(contacts.requestReadAccess)) {
        case ContactsAccess.granted:
          break;
        case ContactsAccess.denied:
          throw ContactImportFailure.permissionDenied;
        case ContactsAccess.blocked:
          throw ContactImportFailure.permissionBlocked;
      }
      return [
        for (final contact in await _guard(contacts.fetchBirthdays))
          BirthdayDraft(
            name: contact.name,
            surname: contact.surname,
            date: BirthDate(
              year: contact.year,
              month: contact.month,
              day: contact.day,
            ),
          ),
      ];
    });
    if (ref.mounted) state = result;
  }

  /// Relit le répertoire si l'accès a été accordé entre-temps (retour des
  /// réglages), sans rien redemander.
  Future<void> reloadIfAllowed() async {
    if (state.isLoading) return;
    final access = await _guard(ref.read(contactsServiceProvider).readAccess)
        .catchError((Object _) => ContactsAccess.denied);
    if (!ref.mounted || access != ContactsAccess.granted) return;
    await load();
  }

  /// Ouvre la page de l'app dans les réglages du téléphone.
  Future<void> openAppSettings() =>
      ref.read(contactsServiceProvider).openAppSettings();

  /// Ajoute [drafts] sans attendre le serveur : Firestore les montre tout de
  /// suite, hors ligne compris. Renvoie leur nombre ; 0 sans session.
  int add(List<BirthdayDraft> drafts) {
    final uid = ref.read(currentUidProvider);
    if (uid == null || drafts.isEmpty) return 0;
    unawaited(
      ref
          .read(birthdayRepositoryProvider)
          .createBirthdays(uid, drafts)
          .catchError((Object error) {
            // Refus du serveur (règles) : un bug, pas une action utilisateur.
            debugPrint('[ContactImport] batch rejected: $error');
          }),
    );
    return drafts.length;
  }

  /// Une erreur du plugin devient [ContactImportFailure.unreadable].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ContactImportFailure {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[ContactImport] contacts plugin failed: $error');
      Error.throwWithStackTrace(ContactImportFailure.unreadable, stackTrace);
    }
  }
}

final contactImportProvider =
    AsyncNotifierProvider.autoDispose<ContactImport, List<BirthdayDraft>?>(
      ContactImport.new,
    );

/// Aperçu de l'import : les contacts lus, départagés avec les anniversaires
/// actuels ([previewContactImport]) — à jour si la liste change pendant que
/// l'écran est ouvert. Mêmes états que [contactImportProvider].
final contactImportPreviewProvider =
    Provider.autoDispose<AsyncValue<ContactImportPreview?>>((ref) {
      final existing = ref.watch(birthdaysListProvider);
      final today = ref.watch(todayProvider);
      return ref
          .watch(contactImportProvider)
          .whenData(
            (contacts) => contacts == null
                ? null
                : previewContactImport(
                    contacts,
                    existing: existing,
                    today: today,
                  ),
          );
    });

/// Contacts décochés dans l'aperçu : tous sont cochés au départ.
class ContactImportExclusions extends Notifier<Set<BirthdayDraft>> {
  @override
  Set<BirthdayDraft> build() => const {};

  void toggle(BirthdayDraft contact) => state = state.contains(contact)
      ? {
          for (final excluded in state)
            if (excluded != contact) excluded,
        }
      : {...state, contact};

  /// Décoche tout quand tout est coché, sinon coche tout.
  void toggleAll(List<BirthdayDraft> contacts) =>
      state = state.isEmpty ? contacts.toSet() : const {};
}

final contactImportExclusionsProvider =
    NotifierProvider.autoDispose<ContactImportExclusions, Set<BirthdayDraft>>(
      ContactImportExclusions.new,
    );

/// Contacts à ajouter : les nouveaux de l'aperçu, sauf les décochés.
final contactImportTickedProvider = Provider.autoDispose<List<BirthdayDraft>>((
  ref,
) {
  final fresh = ref.watch(contactImportPreviewProvider).value?.fresh;
  final excluded = ref.watch(contactImportExclusionsProvider);
  return [
    for (final contact in fresh ?? const <BirthdayDraft>[])
      if (!excluded.contains(contact)) contact,
  ];
});
