import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserProfile(
  id: 'user-1',
  name: 'Quentin',
  surname: 'Maillard',
  locale: 'fr',
);

void main() {
  late FakeAuthRepository auth;
  late RecordingBirthdayRepository birthdays;
  late RecordingBookRepository books;
  late RecordingCategoryRepository categories;
  late RecordingUserRepository users;

  ProviderContainer makeContainer({
    String? uid = 'user-1',
    SignInMethod method = SignInMethod.email,
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        birthdayRepositoryProvider.overrideWithValue(birthdays),
        bookRepositoryProvider.overrideWithValue(books),
        categoryRepositoryProvider.overrideWithValue(categories),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue(uid),
        signInMethodProvider.overrideWithValue(method),
      ],
    );
    container.listen(accountDeletionProvider, (_, _) {});
    return container;
  }

  Future<bool> delete(ProviderContainer container, {String? password}) =>
      container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: password);

  /// Rien d'effacé : ni données ni profil.
  void expectNothingErased() {
    expect(birthdays.erasedUids, isEmpty);
    expect(books.erasedUids, isEmpty);
    expect(categories.erasedUids, isEmpty);
    expect(users.deleted, isEmpty);
  }

  setUp(() {
    auth = FakeAuthRepository(user: MockUser(uid: 'user-1'));
    birthdays = RecordingBirthdayRepository();
    books = RecordingBookRepository();
    categories = RecordingCategoryRepository(const []);
    users = RecordingUserRepository(stored: _user);
  });

  test('confirms the identity, erases the data, then the account', () async {
    final container = makeContainer();

    expect(await delete(container, password: 'pw'), isTrue);

    expect(auth.reauthPasswords, ['pw']);
    expect(birthdays.erasedUids, ['user-1']);
    expect(books.erasedUids, ['user-1']);
    expect(categories.erasedUids, ['user-1']);
    expect(users.deleted, ['user-1']);
    expect(auth.calls, [
      'reauthenticateWithPassword',
      'deleteCurrentUser',
      'signOutFirebase',
      'signOutGoogle',
    ]);
    expect(container.read(accountDeletionProvider), isA<AsyncData<void>>());
  });

  test('erases nothing when the password is refused', () async {
    auth = FakeAuthRepository(
      user: MockUser(uid: 'user-1'),
      reauthFailure: AuthFailure.invalidCredentials,
    );
    final container = makeContainer();

    expect(await delete(container, password: 'no'), isFalse);

    expectNothingErased();
    expect(auth.calls, isNot(contains('deleteCurrentUser')));
    expect(
      container.read(accountDeletionProvider).error,
      AuthFailure.invalidCredentials,
    );
  });

  test('a guest has nothing to confirm', () async {
    final container = makeContainer(method: SignInMethod.guest);

    expect(await delete(container), isTrue);

    expect(auth.calls.first, 'deleteCurrentUser');
    expect(users.deleted, ['user-1']);
  });

  test('does nothing without a session', () async {
    final container = makeContainer(uid: null);

    expect(await delete(container), isFalse);

    expectNothingErased();
    expect(auth.calls, isEmpty);
  });

  test('keeps the profile and the account when the books stay', () async {
    books = RecordingBookRepository(failure: Exception('denied'));
    final container = makeContainer();

    expect(await delete(container, password: 'pw'), isFalse);

    expect(users.deleted, isEmpty);
    expect(auth.calls, isNot(contains('deleteCurrentUser')));
    expect(container.read(accountDeletionProvider).hasError, isTrue);
  });

  test('keeps the profile when the groups cannot be erased', () async {
    categories = RecordingCategoryRepository(
      const [],
      failure: Exception('denied'),
    );
    final container = makeContainer();

    expect(await delete(container, password: 'pw'), isFalse);

    expect(users.deleted, isEmpty);
  });

  test('publishes a refused account deletion', () async {
    auth = FakeAuthRepository(
      user: MockUser(uid: 'user-1'),
      deleteFailure: AuthFailure.network,
    );
    final container = makeContainer();

    expect(await delete(container, password: 'pw'), isFalse);

    expect(container.read(accountDeletionProvider).error, AuthFailure.network);
  });
}
