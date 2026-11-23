import 'dart:async';

import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Liaisons aux contacts du compte connecté, sur ce téléphone : id de fiche →
/// numéro choisi (P5). Dérivées de la session : vides hors session, celles
/// d'un autre compte jamais lues.
///
/// Elles ne viennent pas d'un flux Firestore mais du stockage de l'appareil :
/// ce notifier les garde en mémoire et les écrit lui-même, une écriture
/// après l'autre (chacune remplace l'entrée entière du compte).
class ContactLinks extends AsyncNotifier<Map<String, ContactLink>> {
  /// Dernière écriture lancée : la suivante attend sa fin.
  Future<void> _writes = Future<void>.value();

  @override
  Future<Map<String, ContactLink>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const {};
    return ref.watch(contactLinkRepositoryProvider).fetchLinks(uid);
  }

  /// Relie la fiche [birthdayId] à [link], ou remplace sa liaison. Lève
  /// [ContactLinkFailure.storageFailed], la liaison d'avant rétablie.
  Future<void> link(String birthdayId, ContactLink link) =>
      _update((links) => {...links, birthdayId: link});

  /// Délie la fiche [birthdayId] : son numéro est effacé de ce téléphone.
  /// Lève [ContactLinkFailure.storageFailed], la liaison rétablie.
  Future<void> unlink(String birthdayId) => _update(
    (links) => {
      for (final entry in links.entries)
        if (entry.key != birthdayId) entry.key: entry.value,
    },
  );

  Future<void> _update(
    Map<String, ContactLink> Function(Map<String, ContactLink> links) change,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final before = await future;
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
    final after = change(state.value ?? before);
    state = AsyncData(after);
    final repository = ref.read(contactLinkRepositoryProvider);
    final write = _writes.then((_) => repository.saveLinks(uid, after));
    // La chaîne continue après un échec : il est rendu à l'appelant.
    _writes = write.then<void>((_) {}, onError: (_) {});
    try {
      await write;
    } catch (_) {
      // Relire la vérité du stockage : un état d'avant rétabli contiendrait
      // peut-être une autre modification, elle aussi refusée.
      if (ref.mounted) ref.invalidateSelf();
      rethrow;
    }
  }
}

final contactLinksProvider =
    AsyncNotifierProvider<ContactLinks, Map<String, ContactLink>>(
      ContactLinks.new,
    );

/// Liaison de la fiche [birthdayId] ; null tant qu'elle n'est pas liée (ou
/// pendant la lecture).
final contactLinkProvider = Provider.autoDispose.family<ContactLink?, String>(
  (ref, birthdayId) => ref.watch(
    contactLinksProvider.select((links) => links.value?[birthdayId]),
  ),
);

/// Vrai là où une personne peut être reliée à son contact (Android).
final contactLinkSupportedProvider = Provider<bool>(
  (ref) => ref.watch(phoneContactServiceProvider).isSupported,
);

/// Actions de la liaison : choisir le numéro, délier, appeler et écrire hors
/// du vœu. État : `AsyncLoading` pendant le sélecteur, `AsyncError` portant
/// un [ContactLinkFailure], sinon `AsyncData`.
class ContactLinker extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Ouvre le sélecteur de numéros du système et relie [birthdayId] au
  /// numéro choisi. Vrai une fois relié ; faux si le sélecteur est fermé
  /// sans choix, déjà ouvert, ou en échec (publié dans l'état).
  Future<bool> pick(String birthdayId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final picked = await ref.read(phoneContactServiceProvider).pickPhone();
      if (!ref.mounted) return false;
      if (picked == null) {
        state = const AsyncData(null);
        return false;
      }
      await ref
          .read(contactLinksProvider.notifier)
          .link(
            birthdayId,
            ContactLink(number: picked.number, contactName: picked.contactName),
          );
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on PhoneContactUnavailable catch (_, stackTrace) {
      _fail(ContactLinkFailure.pickerUnavailable, stackTrace);
      return false;
    } on ContactLinkFailure catch (failure, stackTrace) {
      _fail(failure, stackTrace);
      return false;
    }
  }

  /// Délie [birthdayId] et renvoie la liaison retirée, pour « Annuler » ;
  /// null si elle n'était pas liée ou si l'effacement a échoué (publié).
  Future<ContactLink?> unlink(String birthdayId) async {
    final links = ref.read(contactLinksProvider.notifier);
    final link = (await ref.read(contactLinksProvider.future))[birthdayId];
    if (link == null) return null;
    try {
      await links.unlink(birthdayId);
      _done();
      return link;
    } on ContactLinkFailure catch (failure, stackTrace) {
      _fail(failure, stackTrace);
      return null;
    }
  }

  /// Rétablit [link] sur [birthdayId] (« Annuler » après [unlink]).
  Future<void> restore(String birthdayId, ContactLink link) async {
    try {
      await ref.read(contactLinksProvider.notifier).link(birthdayId, link);
      _done();
    } on ContactLinkFailure catch (failure, stackTrace) {
      _fail(failure, stackTrace);
    }
  }

  /// Ouvre le composeur avec [number] ; vrai s'il s'est ouvert.
  Future<bool> dial(String number) =>
      _open(ref.read(phoneContactServiceProvider).dial(number));

  /// Ouvre la conversation SMS avec [number], [text] déjà écrit ; vrai si
  /// elle s'est ouverte.
  Future<bool> message(String number, String text) =>
      _open(ref.read(phoneContactServiceProvider).sendSms(number, text));

  Future<bool> _open(Future<bool> opening) async {
    final opened = await opening;
    if (opened) {
      _done();
    } else {
      _fail(ContactLinkFailure.appUnavailable, StackTrace.current);
    }
    return opened;
  }

  /// Un geste réussi efface l'échec d'avant.
  void _done() {
    if (ref.mounted) state = const AsyncData(null);
  }

  void _fail(ContactLinkFailure failure, StackTrace stackTrace) {
    if (ref.mounted) state = AsyncError(failure, stackTrace);
  }
}

final contactLinkerProvider =
    AsyncNotifierProvider.autoDispose<ContactLinker, void>(ContactLinker.new);
