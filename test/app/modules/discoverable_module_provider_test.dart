import 'package:an_ki/app/modules/module_discovery.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserProfile profile({
    String id = 'u1',
    Map<String, bool> modules = const {},
  }) => UserProfile(id: id, name: 'A', surname: 'B', moduleChoices: modules);

  /// Le module à présenter pour la session [uid] et le profil [value].
  String? discoverable({
    String? uid = 'u1',
    AsyncValue<UserProfile?> value = const AsyncLoading(),
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        userProfileProvider.overrideWithValue(value),
      ],
    );
    container.listen(discoverableModuleProvider, (_, _) {});
    return container.read(discoverableModuleProvider)?.id;
  }

  test('offers Books when the profile has no choice for it', () {
    expect(discoverable(value: AsyncData(profile())), 'books');
    // Un autre module choisi ne retire pas la carte de Livres.
    expect(
      discoverable(value: AsyncData(profile(modules: const {'x': true}))),
      'books',
    );
  });

  test('offers nothing once Books has a choice, either way', () {
    expect(
      discoverable(value: AsyncData(profile(modules: const {'books': false}))),
      isNull,
    );
    expect(
      discoverable(value: AsyncData(profile(modules: const {'books': true}))),
      isNull,
    );
  });

  test('offers nothing without a session, a loaded profile or its own', () {
    expect(discoverable(uid: null, value: AsyncData(profile())), isNull);
    expect(discoverable(), isNull);
    expect(discoverable(value: const AsyncData(null)), isNull);
    // Le profil d'un compte précédent, gardé pendant le changement.
    expect(discoverable(value: AsyncData(profile(id: 'u0'))), isNull);
  });
}
