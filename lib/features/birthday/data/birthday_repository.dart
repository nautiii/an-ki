import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
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
  Stream<List<BirthdayModel>> watchBirthdays(String uid) => _birthdays
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_birthdayFromDoc).nonNulls.toList());

  Future<void> createBirthday(String uid, BirthdayDraft draft) =>
      _birthdays.add({..._draftToMap(draft), 'uid': uid});

  /// Crée plusieurs anniversaires (import de contacts), par lots de
  /// [_batchLimit] écritures. Tous les lots partent d'un coup : Firestore les
  /// applique au cache local immédiatement, le Future attend le serveur.
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) {
    final commits = <Future<void>>[];
    for (var start = 0; start < drafts.length; start += _batchLimit) {
      final batch = _firestore.batch();
      for (final draft in drafts.skip(start).take(_batchLimit)) {
        batch.set(_birthdays.doc(), {..._draftToMap(draft), 'uid': uid});
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits);
  }

  /// Limite Firestore d'écritures par lot.
  static const _batchLimit = 500;

  /// Remplace les champs saisis ; la photo n'est réécrite que si le brouillon
  /// en apporte une nouvelle.
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) => _birthdays.doc(birthdayId).update({..._draftToMap(draft), 'uid': uid});

  /// Supprime un anniversaire. La propriété du document est vérifiée par les
  /// règles Firestore : pas de lecture préalable, qui retarderait l'écriture.
  Future<void> deleteBirthday(String birthdayId) =>
      _birthdays.doc(birthdayId).delete();

  Future<void> deleteAllUserBirthdays(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _birthdays
        .where('uid', isEqualTo: uid)
        .get();

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(firestore: ref.watch(firestoreProvider)),
);

// Conversion Firestore ↔ domaine : privée au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
BirthdayModel? _birthdayFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final date = (data['date'] as Timestamp?)?.toDate();
  if (date == null) return null;
  return BirthdayModel(
    id: doc.id,
    name: data['name'] as String? ?? '',
    surname: data['surname'] as String? ?? '',
    date: date,
    categories: List<String>.from(
      data['categories'] as List<dynamic>? ?? const [],
    ),
    picture: _decodePicture(data['picture'] as String?),
  );
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

Map<String, Object> _draftToMap(BirthdayDraft draft) => {
  'name': draft.name.trim(),
  'surname': draft.surname.trim(),
  'date': Timestamp.fromDate(draft.date),
  'categories': draft.categories,
  if (draft.picture case final picture?) 'picture': base64Encode(picture),
};
