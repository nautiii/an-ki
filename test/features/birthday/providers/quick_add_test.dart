import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/quick_add.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  /// Le mode retenu pour la session `u1`, avec le profil [stored].
  Future<bool> preferred(UserProfile? stored) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        userRepositoryProvider.overrideWithValue(
          RecordingUserRepository(stored: stored),
        ),
      ],
    );
    container.listen(quickAddPreferredProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(quickAddPreferredProvider);
  }

  test('is the form while the profile loads or is missing', () async {
    expect(await preferred(null), isFalse);
  });

  test('is the form by default', () async {
    expect(
      await preferred(const UserProfile(id: 'u1', name: 'A', surname: 'B')),
      isFalse,
    );
  });

  test('is the line once picked', () async {
    expect(
      await preferred(
        const UserProfile(
          id: 'u1',
          name: 'A',
          surname: 'B',
          quickAddPreferred: true,
        ),
      ),
      isTrue,
    );
  });

  test("ignores another account's profile", () async {
    expect(
      await preferred(
        const UserProfile(
          id: 'u2',
          name: 'A',
          surname: 'B',
          quickAddPreferred: true,
        ),
      ),
      isFalse,
    );
  });
}
