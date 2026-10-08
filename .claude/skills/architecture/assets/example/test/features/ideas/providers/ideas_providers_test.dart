import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/ideas/providers/ideas_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session pilotable par le test (connexion, changement de compte…).
final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void signIn(String? uid) => state = uid;
}

void main() {
  late FakeFirebaseFirestore firestore;

  Future<void> seed(String uid, String id, {String? personId}) =>
      firestore.collection('user').doc(uid).collection('ideas').doc(id).set({
        'title': id,
        'personId': ?personId,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });

  ProviderContainer makeContainer() => ProviderContainer.test(
    // Pas de nouvelle tentative automatique : une erreur reste une erreur.
    retry: (_, _) => null,
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      currentUidProvider.overrideWith((ref) => ref.watch(_session)),
    ],
  );

  setUp(() => firestore = FakeFirebaseFirestore());

  test('ideasProvider streams the ideas of the signed-in user', () async {
    await seed('u1', 'mine');
    await seed('u2', 'theirs');
    final container = makeContainer();
    // Riverpod 3 met en pause un StreamProvider sans listener : sans ce
    // listen, `.future` ne se résoudrait jamais.
    container.listen(ideasProvider, (_, _) {});

    final ideas = await container.read(ideasProvider.future);

    expect(ideas.map((i) => i.id), ['mine']);
  });

  test('ideasProvider follows the session without manual reset', () async {
    await seed('u1', 'mine');
    await seed('u2', 'theirs');
    final container = makeContainer();
    container.listen(ideasProvider, (_, _) {});
    await container.read(ideasProvider.future);

    container.read(_session.notifier).signIn('u2');
    expect((await container.read(ideasProvider.future)).single.id, 'theirs');

    container.read(_session.notifier).signIn(null);
    expect(await container.read(ideasProvider.future), isEmpty);
  });

  test('personIdeasProvider keeps the ideas of one person', () async {
    await seed('u1', 'for-lea', personId: 'lea');
    await seed('u1', 'unassigned');
    final container = makeContainer();
    container.listen(personIdeasProvider('lea'), (_, _) {});

    await container.read(ideasProvider.future);

    expect(
      container.read(personIdeasProvider('lea')).requireValue.map((i) => i.id),
      ['for-lea'],
    );
  });
}
