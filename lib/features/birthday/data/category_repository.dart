import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(firestore: ref.watch(firestoreProvider)),
);

/// Catégories, présentées comme des groupes : la collection partagée
/// `category` (prédéfinies, et groupes créés avant qu'ils soient privés),
/// lue par tous les utilisateurs connectés ; les groupes créés désormais,
/// privés, sous `user/{uid}/categories`.
class CategoryRepository {
  CategoryRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _own(String uid) =>
      _db.collection('user').doc(uid).collection('categories');

  Stream<List<BirthdayCategory>> watchCategories() => _db
      .collection('category')
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

  /// Efface les groupes privés de [uid] (suppression du compte) : Firestore
  /// ne supprime pas une sous-collection avec son document parent.
  Future<void> deleteAllUserCategories(String uid) async {
    final snapshot = await _own(uid).get();
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
