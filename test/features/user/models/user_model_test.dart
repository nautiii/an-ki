import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<DocumentSnapshot<Map<String, dynamic>>> seed(
    String id,
    Map<String, dynamic> data,
  ) async {
    await firestore.collection('user').doc(id).set(data);
    return firestore.collection('user').doc(id).get();
  }

  group('UserModel.fromFirestore', () {
    test('maps a complete document', () async {
      final doc = await seed('user-1', {
        'name': 'Quentin',
        'surname': 'Maillard',
        'pseudo': 'Q',
        'categories': ['family', 'friend'],
        'isDark': true,
        'locale': 'en',
        'biometricToken': 'token-123',
      });

      final model = UserModel.fromFirestore(doc);

      expect(model.id, 'user-1');
      expect(model.name, 'Quentin');
      expect(model.surname, 'Maillard');
      expect(model.pseudo, 'Q');
      expect(model.categories, ['family', 'friend']);
      expect(model.isDark, isTrue);
      expect(model.locale, 'en');
      expect(model.biometricToken, 'token-123');
    });

    test('applies defaults for missing fields', () async {
      final doc = await seed('user-2', <String, dynamic>{});

      final model = UserModel.fromFirestore(doc);

      expect(model.name, '');
      expect(model.surname, '');
      expect(model.pseudo, isNull);
      expect(model.categories, isEmpty);
      expect(model.isDark, isFalse);
      expect(model.locale, 'fr');
      expect(model.biometricToken, isNull);
    });
  });

  group('UserModel.toJson', () {
    test('omits null pseudo and biometricToken', () {
      const model = UserModel(
        id: '1',
        name: 'A',
        surname: 'B',
        isDark: false,
        locale: 'fr',
      );

      final json = model.toJson();

      expect(json.containsKey('pseudo'), isFalse);
      expect(json.containsKey('biometricToken'), isFalse);
      expect(json['name'], 'A');
      expect(json['categories'], isEmpty);
      expect(json['isDark'], isFalse);
      expect(json['locale'], 'fr');
    });

    test('includes pseudo and biometricToken when present', () {
      const model = UserModel(
        id: '1',
        name: 'A',
        surname: 'B',
        pseudo: 'pp',
        isDark: true,
        locale: 'en',
        biometricToken: 'tok',
      );

      final json = model.toJson();

      expect(json['pseudo'], 'pp');
      expect(json['biometricToken'], 'tok');
    });
  });

  test('copyWith overrides selected fields and keeps the rest', () {
    const base = UserModel(
      id: '1',
      name: 'A',
      surname: 'B',
      pseudo: 'old',
      categories: ['x'],
      isDark: false,
      locale: 'fr',
    );

    final copy = base.copyWith(pseudo: 'new', isDark: true, locale: 'en');

    expect(copy.pseudo, 'new');
    expect(copy.isDark, isTrue);
    expect(copy.locale, 'en');
    expect(copy.id, '1');
    expect(copy.categories, ['x']);
    expect(base.copyWith().name, 'A');
  });
}
