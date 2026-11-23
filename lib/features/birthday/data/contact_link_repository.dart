import 'dart:convert';

import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Liaisons aux contacts (P5), rangées sur ce téléphone seulement : dans le
/// stockage chiffré de l'appareil, une entrée par compte (`contact_links_<uid>`,
/// un JSON `{id de fiche: {number, name}}`). Aucune donnée ne part vers
/// Firestore ; un autre compte sur le même téléphone ne lit pas celles-ci.
class ContactLinkRepository {
  const ContactLinkRepository(this._storage);

  final FlutterSecureStorage _storage;

  static String _key(String uid) => 'contact_links_$uid';

  /// Liaisons du compte [uid] ; vide sans entrée, ou quand l'entrée est
  /// illisible (une entrée abîmée ne doit pas casser la fiche).
  Future<Map<String, ContactLink>> fetchLinks(String uid) async {
    final Object? decoded;
    try {
      final raw = await _storage.read(key: _key(uid));
      if (raw == null) return const {};
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    } on Exception {
      // Stockage illisible (clé de chiffrement perdue, plugin absent) : rien
      // de relié.
      return const {};
    }
    if (decoded is! Map<String, Object?>) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries) key: ?_link(value),
    };
  }

  /// Remplace les liaisons du compte [uid] par [links] ; aucune → l'entrée
  /// disparaît. Lève [ContactLinkFailure.storageFailed].
  Future<void> saveLinks(String uid, Map<String, ContactLink> links) {
    if (links.isEmpty) return deleteAllUserLinks(uid);
    return _guard(
      () => _storage.write(
        key: _key(uid),
        value: jsonEncode({
          for (final MapEntry(:key, :value) in links.entries)
            key: {'number': value.number, 'name': value.contactName},
        }),
      ),
    );
  }

  /// Efface toutes les liaisons du compte [uid] de ce téléphone. Lève
  /// [ContactLinkFailure.storageFailed].
  Future<void> deleteAllUserLinks(String uid) =>
      _guard(() => _storage.delete(key: _key(uid)));

  static Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (_, stackTrace) {
      Error.throwWithStackTrace(ContactLinkFailure.storageFailed, stackTrace);
    }
  }

  /// Liaison lue d'une valeur JSON ; null sans numéro.
  static ContactLink? _link(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final number = value['number'];
    if (number is! String || number.trim().isEmpty) return null;
    final name = value['name'];
    return ContactLink(number: number, contactName: name is String ? name : '');
  }
}

/// Liaisons aux contacts de ce téléphone ; les tests le remplacent.
final contactLinkRepositoryProvider = Provider<ContactLinkRepository>(
  (ref) => const ContactLinkRepository(FlutterSecureStorage()),
);
