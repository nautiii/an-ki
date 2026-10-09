import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(firestore: ref.watch(firestoreProvider)),
);

/// Catégories : collection Firestore `category`, partagée par tous les
/// utilisateurs connectés (chacun choisit les siennes dans son profil).
class CategoryRepository {
  CategoryRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

  Stream<List<BirthdayCategory>> watchCategories() => _db
      .collection('category')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_categoryFromDoc).toList());

  Future<String> createCategory(BirthdayCategory category) async {
    final docRef = await _db
        .collection('category')
        .add(_categoryToMap(category));
    return docRef.id;
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
  );
}

Map<String, Object> _categoryToMap(BirthdayCategory category) => {
  'name': category.name,
  'icon': category.icon,
};
