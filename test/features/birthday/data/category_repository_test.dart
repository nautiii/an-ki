import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    test('maps every predefined category, and only them', () async {
      final family = await firestore.collection('category').add({
        'name': 'Family',
        'icon': 1,
        'predefined': true,
      });
      final friend = await firestore.collection('category').add({
        'name': 'Friend',
        'icon': 2,
        'predefined': true,
      });
      // Ancien groupe partagé, désormais copié chez son propriétaire.
      await firestore.collection('category').add({'name': 'Club', 'icon': 3});

      final categories = await repository.watchCategories().first;

      expect(categories.toSet(), {
        BirthdayCategory(id: family.id, name: 'Family', icon: 1),
        BirthdayCategory(id: friend.id, name: 'Friend', icon: 2),
      });
    });

    test('falls back to defaults for an old document', () async {
      await firestore.collection('category').add({'predefined': true});

      final category = (await repository.watchCategories().first).single;

      expect(category.name, '');
      expect(category.icon, Icons.category.codePoint);
    });
  });

  test('newCategoryId generates distinct local ids', () {
    final first = repository.newCategoryId();

    expect(first, isNotEmpty);
    expect(repository.newCategoryId(), isNot(first));
  });

  CollectionReference<Map<String, dynamic>> own(String uid) =>
      firestore.collection('user').doc(uid).collection('categories');

  group('private groups', () {
    test('createCategory stores the group under its owner', () async {
      final id = repository.newCategoryId();

      await repository.createCategory(
        'u1',
        BirthdayCategory(id: id, name: 'Voisins', icon: 42, tone: 4),
      );

      final doc = await own('u1').doc(id).get();
      expect(doc.data(), {'name': 'Voisins', 'icon': 42, 'tone': 4});
      final shared = await firestore.collection('category').get();
      expect(shared.docs, isEmpty);
    });

    test('a group without tone is stored without the field', () async {
      await repository.createCategory(
        'u1',
        const BirthdayCategory(id: 'g', name: 'Voisins', icon: 42),
      );

      expect((await own('u1').doc('g').get()).data(), {
        'name': 'Voisins',
        'icon': 42,
      });
    });

    test('watchOwnCategories streams only the owner groups', () async {
      await own('u1')
          .doc('mine')
          .set({'name': 'Voisins', 'icon': 1, 'tone': 4});
      await own('u2').doc('theirs').set({'name': 'Secret', 'icon': 2});

      final groups = await repository.watchOwnCategories('u1').first;

      expect(groups, [
        const BirthdayCategory(id: 'mine', name: 'Voisins', icon: 1, tone: 4),
      ]);
    });

    test('updateCategory rewrites the name and the tone', () async {
      await own('u1').doc('g').set({'name': 'Voisins', 'icon': 42, 'tone': 4});

      await repository.updateCategory(
        'u1',
        const BirthdayCategory(id: 'g', name: 'Voisinage', icon: 42, tone: 9),
      );

      expect((await own('u1').doc('g').get()).data(), {
        'name': 'Voisinage',
        'icon': 42,
        'tone': 9,
      });
    });

    test('deleteCategory erases one group of its owner', () async {
      await own('u1').doc('a').set({'name': 'A', 'icon': 1});
      await own('u1').doc('b').set({'name': 'B', 'icon': 1});

      await repository.deleteCategory('u1', 'a');

      final left = await own('u1').get();
      expect(left.docs.map((doc) => doc.id), ['b']);
    });

    Future<String> person(List<String> categories) async =>
        (await firestore.collection('birthday').add({
          'uid': 'u1',
          'name': 'P',
          'surname': '',
          'date': Timestamp.fromDate(DateTime(1990)),
          'categories': categories,
        })).id;

    Future<List<dynamic>> categoriesOf(String id) async =>
        (await firestore.collection('birthday').doc(id).get())
                .data()!['categories']
            as List<dynamic>;

    test('deleteCategory drops the group from its carriers only', () async {
      await own('u1').doc('book').set({'name': 'Livres', 'icon': 1});
      final lea = await person(['book', 'family']);
      final tom = await person(['book']);
      final other = await person(['book']);

      await repository.deleteCategory('u1', 'book', carriers: [lea, tom]);

      expect((await own('u1').get()).docs, isEmpty);
      expect(await categoriesOf(lea), ['family']);
      expect(await categoriesOf(tom), isEmpty);
      expect(await categoriesOf(other), ['book']);
    });

    test('deleteCategory without carriers only erases the group', () async {
      await own('u1').doc('book').set({'name': 'Livres', 'icon': 1});
      final lea = await person(['book']);

      await repository.deleteCategory('u1', 'book');

      expect((await own('u1').get()).docs, isEmpty);
      expect(await categoriesOf(lea), ['book']);
    });

    test('deleteCategory spans several batches', () async {
      await own('u1').doc('book').set({'name': 'Livres', 'icon': 1});
      final ids = [
        for (var i = 0; i < 600; i++) await person(['book']),
      ];

      await repository.deleteCategory('u1', 'book', carriers: ids);

      expect((await own('u1').get()).docs, isEmpty);
      final left = await firestore.collection('birthday').get();
      expect(left.docs, hasLength(600));
      expect(
        left.docs.every((doc) => (doc.data()['categories'] as List).isEmpty),
        isTrue,
      );
    });

    test('deleteAllUserCategories erases the owner groups only', () async {
      await own('u1').doc('a').set({'name': 'A', 'icon': 1});
      await own('u1').doc('b').set({'name': 'B', 'icon': 1});
      await own('u2').doc('c').set({'name': 'C', 'icon': 1});

      await repository.deleteAllUserCategories('u1');

      expect((await own('u1').get()).docs, isEmpty);
      expect((await own('u2').get()).docs, hasLength(1));
    });
  });

  test('reads the tone of a shared category when it has one', () async {
    await firestore.collection('category').doc('x').set({
      'name': 'Sport',
      'icon': 1,
      'tone': 9,
      'predefined': true,
    });

    final category = (await repository.watchCategories().first).single;

    expect(category.tone, 9);
  });
}
