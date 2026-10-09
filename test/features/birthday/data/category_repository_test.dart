import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CategoryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CategoryRepository(firestore: firestore);
  });

  group('watchCategories', () {
    test('maps every stored category', () async {
      final family = await firestore.collection('category').add({
        'name': 'Family',
        'icon': 1,
      });
      final friend = await firestore.collection('category').add({
        'name': 'Friend',
        'icon': 2,
      });

      final categories = await repository.watchCategories().first;

      expect(categories.toSet(), {
        BirthdayCategory(id: family.id, name: 'Family', icon: 1),
        BirthdayCategory(id: friend.id, name: 'Friend', icon: 2),
      });
    });

    test('falls back to defaults for an old document', () async {
      await firestore.collection('category').add(<String, dynamic>{});

      final category = (await repository.watchCategories().first).single;

      expect(category.name, '');
      expect(category.icon, Icons.category.codePoint);
    });
  });

  test('createCategory persists the category and returns its id', () async {
    final id = await repository.createCategory(
      const BirthdayCategory(id: '', name: 'Sport', icon: 42),
    );

    final doc = await firestore.collection('category').doc(id).get();
    expect(doc.data(), {'name': 'Sport', 'icon': 42});
  });
}
