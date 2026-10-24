import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  late RecordingCategoryRepository categories;

  ProviderContainer makeContainer({String? uid = 'u'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(categoryEditorProvider, (_, _) {});
    return container;
  }

  setUp(() => categories = RecordingCategoryRepository(const []));

  test('creates a private group and returns its id at once', () async {
    final container = makeContainer();

    final id = container
        .read(categoryEditorProvider.notifier)
        .create(' Club de lecture ', icon: 42, tone: 4);

    expect(id, 'new-cat-1');
    await pumpEventQueue();
    expect(categories.created, [
      const BirthdayCategory(
        id: 'new-cat-1',
        name: 'Club de lecture',
        icon: 42,
        tone: 4,
      ),
    ]);
    expect(categories.createdFor, ['u']);
    expect(container.read(categoryEditorProvider), isA<AsyncData<void>>());
  });

  test('creates nothing without a session', () async {
    final container = makeContainer(uid: null);

    final id = container
        .read(categoryEditorProvider.notifier)
        .create('Voisins', icon: 42, tone: 4);

    expect(id, isNull);
    await pumpEventQueue();
    expect(categories.created, isEmpty);
  });

  test('publishes a failed write as an AsyncError', () async {
    categories = RecordingCategoryRepository(
      const [],
      failure: Exception('permission-denied'),
    );
    final container = makeContainer();

    container
        .read(categoryEditorProvider.notifier)
        .create('Voisins', icon: 42, tone: 4);
    await pumpEventQueue();

    expect(container.read(categoryEditorProvider).hasError, isTrue);
  });
}
