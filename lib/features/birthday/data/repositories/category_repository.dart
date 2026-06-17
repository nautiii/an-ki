import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryRepositoryProvider = Provider((ref) => CategoryRepository());

class CategoryRepository {
  CategoryRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<BirthdayCategory>> watchCategories() {
    return _db.collection('category').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BirthdayCategory.fromFirestore(doc))
          .toList();
    });
  }

  Future<String> createCategory(BirthdayCategory category) async {
    final docRef = await _db.collection('category').add(category.toJson());
    return docRef.id;
  }
}
