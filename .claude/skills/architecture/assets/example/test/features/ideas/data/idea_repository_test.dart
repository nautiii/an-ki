import 'package:an_ki/features/ideas/data/idea_repository.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late IdeaRepository repository;

  CollectionReference<Map<String, dynamic>> ideasOf(String uid) =>
      firestore.collection('user').doc(uid).collection('ideas');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = IdeaRepository(firestore);
  });

  test(
    'watchIdeas only emits the ideas of the given user, newest first',
    () async {
      await ideasOf('u1').doc('old').set({
        'title': 'Ancienne',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });
      await ideasOf('u1').doc('new').set({
        'title': 'Récente',
        'createdAt': Timestamp.fromDate(DateTime(2026, 2)),
      });
      await ideasOf('u2').doc('other').set({
        'title': 'Pas à moi',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3)),
      });

      final ideas = await repository.watchIdeas('u1').first;

      expect(ideas.map((i) => i.id), ['new', 'old']);
    },
  );

  test(
    'addIdea stores the normalized draft and omits empty optionals',
    () async {
      final id = await repository.addIdea(
        'u1',
        const IdeaDraft(title: '  Livre  ', personId: 'p1'),
        now: DateTime(2026, 10, 7),
      );

      final stored = (await ideasOf('u1').doc(id).get()).data();
      expect(stored, {
        'title': 'Livre',
        'personId': 'p1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 7)),
      });
    },
  );

  test('reads old documents with missing fields', () async {
    await ideasOf('u1').doc('legacy').set(<String, dynamic>{});

    final idea = (await repository.watchIdeas('u1').first).single;

    expect(idea.title, isEmpty);
    expect(idea.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('deleteIdea removes the document', () async {
    await ideasOf('u1').doc('i1').set({'title': 'Livre'});

    await repository.deleteIdea('u1', 'i1');

    expect((await ideasOf('u1').doc('i1').get()).exists, isFalse);
  });

  test('translates Firestore errors into IdeaFailure.storage', () async {
    whenCalling(Invocation.method(#delete, null))
        .on(ideasOf('u1').doc('i1'))
        .thenThrow(FirebaseException(plugin: 'x'));

    await expectLater(
      repository.deleteIdea('u1', 'i1'),
      throwsA(IdeaFailure.storage),
    );
  });
}
