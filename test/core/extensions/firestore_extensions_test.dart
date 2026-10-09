import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  test('writes every item, past the 500 operations of a batch', () async {
    final items = [for (var i = 0; i < 1001; i++) i];

    await firestore.writeInBatches(
      items,
      (batch, i) => batch.set(firestore.collection('c').doc('$i'), {'i': i}),
    );

    expect((await firestore.collection('c').get()).docs, hasLength(1001));
  });

  test('does nothing without items', () async {
    await firestore.writeInBatches(
      const <int>[],
      (batch, i) => fail('no write expected'),
    );

    expect((await firestore.collection('c').get()).docs, isEmpty);
  });
}
