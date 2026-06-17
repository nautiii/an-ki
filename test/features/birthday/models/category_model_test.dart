import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<DocumentSnapshot> seed(String id, Map<String, dynamic> data) async {
    await firestore.collection('category').doc(id).set(data);
    return firestore.collection('category').doc(id).get();
  }

  group('BirthdayCategory.fromFirestore', () {
    test('maps a complete document', () async {
      final doc = await seed('cat-1', {'name': 'Family', 'icon': 0xe300});

      final model = BirthdayCategory.fromFirestore(doc);

      expect(model.id, 'cat-1');
      expect(model.name, 'Family');
      expect(model.icon, 0xe300);
    });

    test('falls back to defaults for missing fields', () async {
      final doc = await seed('cat-2', <String, dynamic>{});

      final model = BirthdayCategory.fromFirestore(doc);

      expect(model.name, '');
      expect(model.icon, Icons.category.codePoint);
    });
  });

  test('iconData exposes a MaterialIcons IconData', () {
    final category = BirthdayCategory(id: '1', name: 'X', icon: 0xe300);

    expect(category.iconData.codePoint, 0xe300);
    expect(category.iconData.fontFamily, 'MaterialIcons');
  });

  test('toJson serializes name and icon only', () {
    final json = BirthdayCategory(id: '1', name: 'Sport', icon: 42).toJson();

    expect(json, {'name': 'Sport', 'icon': 42});
  });

  test('copyWith overrides selected fields', () {
    final base = BirthdayCategory(id: '1', name: 'A', icon: 1);
    final copy = base.copyWith(name: 'B', icon: 2);

    expect(copy.id, '1');
    expect(copy.name, 'B');
    expect(copy.icon, 2);
    expect(base.copyWith().name, 'A');
  });

  group('equality', () {
    test('two categories with the same id are equal', () {
      final a = BirthdayCategory(id: '1', name: 'A', icon: 1);
      final b = BirthdayCategory(id: '1', name: 'Different', icon: 999);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
    });

    test('different ids are not equal', () {
      final a = BirthdayCategory(id: '1', name: 'A', icon: 1);
      final b = BirthdayCategory(id: '2', name: 'A', icon: 1);

      expect(a, isNot(equals(b)));
    });
  });
}
