import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anniversaires : collection Firestore `birthday`, documents portant le
/// `uid` de leur propriétaire (chaque requête filtre dessus).
///
/// Convertit documents ↔ domaine, photo base64 comprise. Ni logique métier,
/// ni texte d'UI, ni état.
class BirthdayRepository {
  BirthdayRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _birthdays =>
      _firestore.collection('birthday');

  /// Anniversaires de [uid] en temps réel. Un document sans date, illisible,
  /// est ignoré plutôt que de faire échouer toute la liste.
  Stream<List<Birthday>> watchBirthdays(String uid) => _birthdays
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_birthdayFromDoc).nonNulls.toList());

  Future<void> createBirthday(String uid, BirthdayDraft draft) =>
      _birthdays.add({..._draftToMap(draft), 'uid': uid});

  /// Crée plusieurs anniversaires (import de contacts), par lots d'écritures
  /// envoyés d'un coup : Firestore les applique au cache local immédiatement,
  /// le Future attend le serveur.
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) =>
      _firestore.writeInBatches(
        drafts,
        (batch, draft) =>
            batch.set(_birthdays.doc(), {..._draftToMap(draft), 'uid': uid}),
      );

  /// Remplace les champs saisis ; la photo n'est réécrite que si le brouillon
  /// en apporte une nouvelle. Revenu au réglage par défaut, l'anniversaire
  /// perd ses rappels propres.
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) => _birthdays.doc(birthdayId).update({
    ..._draftToMap(draft),
    if (draft.reminders == null) 'reminders': FieldValue.delete(),
    'uid': uid,
  });

  /// Marque l'anniversaire de [year] souhaité. `arrayUnion` n'ajoute l'année
  /// qu'une fois et ne touche à aucun autre champ ; la propriété du document
  /// est vérifiée par les règles Firestore.
  Future<void> markWished(String birthdayId, int year) =>
      _birthdays.doc(birthdayId).update({
        'wishedYears': FieldValue.arrayUnion([year]),
      });

  /// Retire [year] des années souhaitées (« Annuler »).
  Future<void> unmarkWished(String birthdayId, int year) =>
      _birthdays.doc(birthdayId).update({
        'wishedYears': FieldValue.arrayRemove([year]),
      });

  /// Supprime un anniversaire. La propriété du document est vérifiée par les
  /// règles Firestore : pas de lecture préalable, qui retarderait l'écriture.
  Future<void> deleteBirthday(String birthdayId) =>
      _birthdays.doc(birthdayId).delete();

  /// Efface tous les anniversaires de [uid] (suppression du compte), par lots
  /// d'écritures : un gros import de contacts dépasse vite la limite d'un lot.
  Future<void> deleteAllUserBirthdays(String uid) async {
    final snapshot = await _birthdays.where('uid', isEqualTo: uid).get();
    await _firestore.writeInBatches(
      snapshot.docs,
      (batch, doc) => batch.delete(doc.reference),
    );
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(firestore: ref.watch(firestoreProvider)),
);

// Conversion Firestore ↔ domaine : privée au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
Birthday? _birthdayFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final date = (data['date'] as Timestamp?)?.toDate();
  if (date == null) return null;
  // Absent des documents écrits avant l'année facultative : année connue.
  final yearKnown = data['yearKnown'] as bool? ?? true;
  return Birthday(
    id: doc.id,
    name: data['name'] as String? ?? '',
    surname: data['surname'] as String? ?? '',
    date: BirthDate(
      year: yearKnown ? date.year : null,
      month: date.month,
      day: date.day,
    ),
    categories: List<String>.from(
      data['categories'] as List<dynamic>? ?? const [],
    ),
    picture: _decodePicture(data['picture'] as String?),
    // Absent des documents écrits avant « souhaité » : jamais souhaité.
    wishedYears: [
      for (final year in data['wishedYears'] as List<dynamic>? ?? const [])
        if (year is int) year,
    ],
    reminders: _remindersFrom(data['reminders']),
  );
}

/// Rappels propres à la personne : absent (documents d'avant B6, ou réglage
/// par défaut) → null ; un nom inconnu (version plus récente) est ignoré.
Set<ReminderLead>? _remindersFrom(Object? stored) {
  if (stored is! List<dynamic>) return null;
  final leads = ReminderLead.values.asNameMap();
  return {
    for (final name in stored)
      ?leads[name],
  };
}

/// Photo stockée en base64 dans le document ; null si absente ou corrompue.
Uint8List? _decodePicture(String? encoded) {
  if (encoded == null) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

/// Année écrite dans `date` quand l'année de naissance est inconnue :
/// bissextile, pour que le 29 février tienne ; `yearKnown: false` dit de
/// l'ignorer.
const _unknownYear = 2000;

// `yearKnown` est toujours écrit : une modification qui ajoute l'année doit
// effacer un `false` précédent (`update` ne touche que les champs donnés).
Map<String, Object> _draftToMap(BirthdayDraft draft) => {
  'name': draft.name.trim(),
  'surname': draft.surname.trim(),
  'date': Timestamp.fromDate(
    DateTime(draft.date.year ?? _unknownYear, draft.date.month, draft.date.day),
  ),
  'yearKnown': draft.date.year != null,
  'categories': draft.categories,
  if (draft.picture case final picture?) 'picture': base64Encode(picture),
  if (draft.reminders case final leads?)
    'reminders': [
      for (final lead in ReminderLead.values)
        if (leads.contains(lead)) lead.name,
    ],
};
