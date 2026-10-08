import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source de vérité des idées : `user/{uid}/ideas/{ideaId}` dans Firestore.
///
/// Convertit documents ↔ [Idea] et traduit les erreurs du SDK en
/// [IdeaFailure]. Ni logique métier, ni texte d'UI, ni état.
class IdeaRepository {
  const IdeaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ideas(String uid) =>
      _firestore.collection('user').doc(uid).collection('ideas');

  /// Idées de [uid] en temps réel, les plus récentes d'abord. Le cache hors
  /// ligne de Firestore émet aussitôt les écritures locales.
  Stream<List<Idea>> watchIdeas(String uid) =>
      _ideas(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_ideaFromDoc).toList());

  /// Crée l'idée et renvoie son id, généré localement.
  ///
  /// Le Future se résout à l'accusé du serveur : hors ligne, seulement au
  /// retour du réseau. L'UI ne l'attend donc pas (écriture optimiste).
  Future<String> addIdea(
    String uid,
    IdeaDraft draft, {
    required DateTime now,
  }) async {
    final doc = _ideas(uid).doc();
    await _guard(() => doc.set(_draftToMap(draft, now)));
    return doc.id;
  }

  Future<void> deleteIdea(String uid, String ideaId) =>
      _guard(() => _ideas(uid).doc(ideaId).delete());

  /// Traduit les erreurs Firestore en [IdeaFailure] en gardant la pile d'origine.
  Future<T> _guard<T>(Future<T> Function() write) async {
    try {
      return await write();
    } on FirebaseException catch (_, stackTrace) {
      Error.throwWithStackTrace(IdeaFailure.storage, stackTrace);
    }
  }
}

final ideaRepositoryProvider = Provider<IdeaRepository>(
  (ref) => IdeaRepository(ref.watch(firestoreProvider)),
);

// Conversion Firestore ↔ domaine : privée au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
Idea _ideaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Idea(
    id: doc.id,
    title: data['title'] as String? ?? '',
    personId: data['personId'] as String?,
    note: data['note'] as String?,
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

Map<String, Object> _draftToMap(IdeaDraft draft, DateTime now) => {
  'title': draft.normalizedTitle,
  'personId': ?draft.personId,
  'note': ?draft.note,
  'createdAt': Timestamp.fromDate(now),
};
