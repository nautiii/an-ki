import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(firestore: ref.watch(firestoreProvider)),
);

/// Catégories, présentées comme des groupes : les prédéfinies de la
/// collection partagée `category` (`predefined: true`), lues par tous les
/// utilisateurs connectés ; les groupes de chacun, privés, sous
/// `user/{uid}/categories`.
class CategoryRepository {
  CategoryRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _own(String uid) =>
      _db.collection('user').doc(uid).collection('categories');

  /// Catégories prédéfinies. Le filtre est obligatoire : les règles refusent
  /// toute requête qui pourrait lire un ancien groupe partagé.
  Stream<List<BirthdayCategory>> watchCategories() => _db
      .collection('category')
      .where('predefined', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_categoryFromDoc).toList());

  /// Groupes privés de [uid], en temps réel.
  Stream<List<BirthdayCategory>> watchOwnCategories(String uid) =>
      _own(uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_categoryFromDoc).toList());

  /// Id d'un nouveau groupe, généré localement : un anniversaire peut le
  /// référencer avant que le serveur ait répondu.
  String newCategoryId() => _db.collection('category').doc().id;

  /// Crée le groupe privé [category] de [uid] sous son id. Le Future se
  /// résout à l'accusé du serveur : l'UI ne l'attend pas.
  Future<void> createCategory(String uid, BirthdayCategory category) =>
      _own(uid).doc(category.id).set(_categoryToMap(category));

  /// Réécrit le nom, l'icône et la teinte du groupe privé [category] de
  /// [uid].
  Future<void> updateCategory(String uid, BirthdayCategory category) =>
      _own(uid).doc(category.id).update(_categoryToMap(category));

  /// Supprime le groupe privé [categoryId] de [uid] et le retire des
  /// anniversaires [carriers] (l'appelant les connaît : pas de requête
  /// `array-contains` ni d'index), dans le même lot : refusé, rien ne change
  /// (un porteur supprimé sur un autre appareil le fait refuser ; un nouvel
  /// essai passe une fois le cache à jour). Au-delà de 499 anniversaires, les
  /// autres lots partent en parallèle, sans atomicité avec le premier : un
  /// échec partiel laisse le groupe, ou son id sur une partie des
  /// anniversaires (ignoré à l'affichage).
  Future<void> deleteCategory(
    String uid,
    String categoryId, {
    Iterable<String> carriers = const [],
  }) {
    final birthdays = _db.collection('birthday');
    return _db.writeInBatches<void Function(WriteBatch)>([
      (batch) => batch.delete(_own(uid).doc(categoryId)),
      for (final birthdayId in carriers)
        (batch) => batch.update(birthdays.doc(birthdayId), {
          'categories': FieldValue.arrayRemove([categoryId]),
        }),
    ], (batch, write) => write(batch));
  }

  /// Groupes privés de [uid] lus une fois (le serveur, ou le cache hors
  /// ligne).
  Future<List<BirthdayCategory>> fetchOwnCategories(String uid) async =>
      (await _own(uid).get()).docs.map(_categoryFromDoc).toList();

  /// Marque les groupes privés de [uid], un invité, pour le compte Google
  /// [email] qui va les reprendre ([takeOver]), et les renvoie. Lus sur le
  /// serveur ; le Future attend l'accusé du serveur.
  Future<List<BirthdayCategory>> markForTransfer(
    String uid,
    String email,
  ) async {
    final snapshot = await _own(uid)
        .get(const GetOptions(source: Source.server));
    await _db.writeInBatches(
      snapshot.docs,
      (batch, doc) => batch.update(doc.reference, {'transferTo': email}),
    );
    return snapshot.docs.map(_categoryFromDoc).toList();
  }

  /// Reprend pour [uid] les groupes de l'invité [guestUid] : [copies] sont
  /// recréés chez lui sous leur id, puis les groupes marqués [guestGroupIds]
  /// de l'invité sont effacés.
  Future<void> takeOver(
    String uid, {
    required String guestUid,
    required Iterable<BirthdayCategory> copies,
    required Iterable<String> guestGroupIds,
  }) => _db.writeInBatches<void Function(WriteBatch)>([
    for (final category in copies)
      (batch) =>
          batch.set(_own(uid).doc(category.id), _categoryToMap(category)),
    for (final id in guestGroupIds)
      (batch) => batch.delete(_own(guestUid).doc(id)),
  ], (batch, write) => write(batch));

  /// Efface les groupes privés de [uid] (suppression du compte) : Firestore
  /// ne supprime pas une sous-collection avec son document parent.
  /// Lu sur le serveur : hors ligne, l'effacement échoue avant de commencer.
  Future<void> deleteAllUserCategories(String uid) async {
    final snapshot = await _own(uid)
        .get(const GetOptions(source: Source.server));
    await _db.writeInBatches(
      snapshot.docs,
      (batch, doc) => batch.delete(doc.reference),
    );
  }
}

/// Point de code de `Icons.category`, icône d'une catégorie qui n'en a pas.
const _defaultIcon = 0xe148;

// Conversion Firestore ↔ domaine : privée au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
BirthdayCategory _categoryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return BirthdayCategory(
    id: doc.id,
    name: data['name'] as String? ?? '',
    icon: data['icon'] as int? ?? _defaultIcon,
    tone: data['tone'] as int?,
  );
}

Map<String, Object> _categoryToMap(BirthdayCategory category) => {
  'name': category.name,
  'icon': category.icon,
  'tone': ?category.tone,
};
