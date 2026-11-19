import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/birthday/providers/quick_add.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  const profile = UserProfile(id: 'u1', name: 'A', surname: 'B');

  Future<(ProviderContainer, RecordingUserRepository)> start({
    UserProfile? stored = profile,
    String uid = 'u1',
  }) async {
    final users = RecordingUserRepository(stored: stored);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    container
      ..listen(quickAddLearnedProvider, (_, _) {})
      ..listen(quickAddLearningProvider, (_, _) {});
    await pumpEventQueue();
    return (container, users);
  }

  void record(ProviderContainer container, {required bool imported}) =>
      container
          .read(birthdayAdditionsProvider.notifier)
          .record(
            BirthdaysAdded(
              count: imported ? 3 : 1,
              imported: imported,
              first: false,
              name: imported ? null : 'Léa',
            ),
          );

  group('quickAddLearnedProvider', () {
    test('is false before the profile loads', () async {
      final (container, _) = await start(stored: null);
      expect(container.read(quickAddLearnedProvider), isFalse);
    });

    test('follows the profile of the signed-in account', () async {
      final (learned, _) = await start(
        stored: const UserProfile(
          id: 'u1',
          name: 'A',
          surname: 'B',
          quickAddLearned: true,
        ),
      );
      expect(learned.read(quickAddLearnedProvider), isTrue);

      final (other, _) = await start(
        stored: const UserProfile(
          id: 'u2',
          name: 'A',
          surname: 'B',
          quickAddLearned: true,
        ),
      );
      expect(other.read(quickAddLearnedProvider), isFalse);
    });
  });

  group('quickAddLearningProvider', () {
    test('learns from the first manual add, once', () async {
      final (container, users) = await start();

      record(container, imported: false);
      await pumpEventQueue();
      expect(users.updated.single.quickAddLearned, isTrue);
      expect(container.read(quickAddLearnedProvider), isTrue);

      record(container, imported: false);
      await pumpEventQueue();
      expect(users.updated, hasLength(1));
    });

    test('an import teaches nothing', () async {
      final (container, users) = await start();

      record(container, imported: true);
      await pumpEventQueue();

      expect(users.updated, isEmpty);
      expect(container.read(quickAddLearnedProvider), isFalse);
    });
  });
}
