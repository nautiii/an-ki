import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:an_ki/features/ideas/providers/idea_editor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> ideasOf(String uid) =>
      firestore.collection('user').doc(uid).collection('ideas');

  ProviderContainer makeContainer({String? uid = 'u1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        currentUidProvider.overrideWithValue(uid),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 7)),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(ideaEditorProvider, (_, _) {});
    return container;
  }

  setUp(() => firestore = FakeFirebaseFirestore());

  test(
    'add writes the idea for the current user with the clock time',
    () async {
      final container = makeContainer();

      await container
          .read(ideaEditorProvider.notifier)
          .add(const IdeaDraft(title: 'Livre'));

      final docs = (await ideasOf('u1').get()).docs;
      expect(docs.single.data()['title'], 'Livre');
      expect(
        docs.single.data()['createdAt'],
        Timestamp.fromDate(DateTime(2026, 10, 7)),
      );
      expect(container.read(ideaEditorProvider), isA<AsyncData<void>>());
    },
  );

  test('add rejects an invalid draft without writing', () async {
    final container = makeContainer();

    await container
        .read(ideaEditorProvider.notifier)
        .add(const IdeaDraft(title: '  '));

    expect(container.read(ideaEditorProvider).error, IdeaFailure.invalidDraft);
    expect((await ideasOf('u1').get()).docs, isEmpty);
  });

  test('reports signedOut when there is no session', () async {
    final container = makeContainer(uid: null);

    await container.read(ideaEditorProvider.notifier).delete('i1');

    expect(container.read(ideaEditorProvider).error, IdeaFailure.signedOut);
  });

  test('exposes storage failures from the repository', () async {
    whenCalling(Invocation.method(#delete, null))
        .on(ideasOf('u1').doc('i1'))
        .thenThrow(FirebaseException(plugin: 'x'));
    final container = makeContainer();

    await container.read(ideaEditorProvider.notifier).delete('i1');

    expect(container.read(ideaEditorProvider).error, IdeaFailure.storage);
  });
}
