import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CategoryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CategoryRepository(firestore: firestore);
  });

  test('watchCategories maps every stored category', () async {
    await firestore.collection('category').add({'name': 'Family', 'icon': 1});
    await firestore.collection('category').add({'name': 'Friend', 'icon': 2});

    final categories = await repository.watchCategories().first;

    expect(categories, hasLength(2));
    expect(categories.map((c) => c.name).toSet(), {'Family', 'Friend'});
  });

  test('createCategory persists the category and returns its id', () async {
    final id = await repository.createCategory(
      BirthdayCategory(id: '', name: 'Sport', icon: 42),
    );

    final doc = await firestore.collection('category').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['name'], 'Sport');
    expect(doc.data()!['icon'], 42);
  });
}
