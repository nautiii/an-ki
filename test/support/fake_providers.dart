import 'dart:async';

import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'fake-uid';

  @override
  String? get displayName => 'Fake User';

  @override
  bool get isAnonymous => false;
}

// --- Repositories ---

class FakeUserRepository extends Fake implements UserRepository {
  @override
  Future<UserModel?> fetchUser(String uid) async => null;

  @override
  Future<UserModel> createUser(UserModel user) async => user;

  @override
  Future<void> updateUser(UserModel user) async {}

  @override
  Future<void> deleteUser(String uid) async {}
}

class FakeBirthdayRepository extends Fake implements BirthdayRepository {
  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) => Stream.value([]);

  @override
  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {}

  @override
  Future<void> createBirthdays(
    String uid,
    List<CreateBirthdayInput> inputs,
  ) async {}

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async {}

  @override
  Future<void> deleteBirthday(String birthdayId) async {}

  @override
  Future<void> deleteAllUserBirthdays(String uid) async {}
}

/// Dépôt d'anniversaires qui sert [initial] par utilisateur et enregistre
/// chaque écriture : les tests observent les effets sans faux notifier.
class RecordingBirthdayRepository extends FakeBirthdayRepository {
  RecordingBirthdayRepository({this.initial = const [], this.failure});

  final List<BirthdayModel> initial;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final watchedUids = <String>[];
  final created = <CreateBirthdayInput>[];
  final updated = <String>[];
  final deleted = <String>[];

  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) {
    watchedUids.add(uid);
    return Stream.value(initial);
  }

  @override
  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {
    _maybeFail();
    created.add(input);
  }

  @override
  Future<void> createBirthdays(
    String uid,
    List<CreateBirthdayInput> inputs,
  ) async {
    _maybeFail();
    created.addAll(inputs);
  }

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async {
    _maybeFail();
    updated.add(birthdayId);
    created.add(input);
  }

  @override
  Future<void> deleteBirthday(String birthdayId) async {
    _maybeFail();
    deleted.add(birthdayId);
  }

  void _maybeFail() {
    if (failure case final failure?) throw failure;
  }
}

class FakeCategoryRepository extends Fake implements CategoryRepository {
  final _categoriesController =
      StreamController<List<BirthdayCategory>>.broadcast();

  void emit(List<BirthdayCategory> categories) =>
      _categoriesController.add(categories);

  @override
  Stream<List<BirthdayCategory>> watchCategories() =>
      _categoriesController.stream;

  @override
  Future<String> createCategory(BirthdayCategory category) async =>
      'new-cat-id';
}

class FakeBookRepository extends Fake implements BookRepository {
  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async => null;

  @override
  Stream<List<BookModel>> watchBooks(String uid) => Stream.value([]);

  @override
  Future<void> saveBook(String uid, BookModel book) async {}

  @override
  Future<void> deleteBook(String bookId) async {}
}

// --- Notifiers ---

class FakeAuthNotifier extends AuthNotifier {
  final AuthState? _initialState;

  FakeAuthNotifier({this._initialState});

  @override
  AuthState build() {
    return _initialState ?? AuthState();
  }

  @override
  void initializeAuth() {}

  @override
  Future<bool> signIn({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async {
    state = state.copyWith(user: MockUser());
    return true;
  }

  @override
  Future<bool> signInAnonymously(AppLocalizations l10n) async {
    state = state.copyWith(user: MockUser());
    return true;
  }

  @override
  Future<bool> signInWithGoogle(AppLocalizations l10n) async {
    state = state.copyWith(user: MockUser());
    return true;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required AppLocalizations l10n,
  }) async {
    state = state.copyWith(user: MockUser());
    return true;
  }

  @override
  Future<bool> linkWithGoogle(AppLocalizations l10n) async {
    return true;
  }

  @override
  Future<void> signOut(AppLocalizations l10n) async {
    state = AuthState();
  }
}

class FakeUserNotifier extends UserNotifier {
  final UserState? _initialState;
  final UserModel? defaultLoadedUser;

  FakeUserNotifier({
    this._initialState,
    this.defaultLoadedUser = const UserModel(
      id: 'default-user',
      name: 'Quentin',
      surname: 'Maillard',
      isDark: false,
      locale: 'fr',
    ),
  });

  @override
  UserState build() {
    return _initialState ?? UserState();
  }

  Completer<UserModel?>? _pendingLoad;

  void preparePendingLoad() {
    _pendingLoad = Completer<UserModel?>();
  }

  void completePendingLoad([UserModel? user]) {
    final completer = _pendingLoad;
    if (completer != null && !completer.isCompleted) {
      completer.complete(user);
    }
  }

  @override
  Future<void> loadUser(String uid) async {
    final completer = _pendingLoad;
    if (completer == null) {
      state = state.copyWith(user: defaultLoadedUser);
      return;
    }

    state = state.copyWith(isLoading: true);
    final user = await completer.future;
    state = state.copyWith(user: user, isLoading: false);
  }

  @override
  void clear() {
    state = UserState();
  }

  @override
  Future<void> createUser({
    required String uid,
    required String name,
    required String surname,
  }) async {
    state = state.copyWith(
      user: UserModel(
        id: uid,
        name: name,
        surname: surname,
        isDark: false,
        locale: 'fr',
      ),
    );
  }

  @override
  Future<void> updatePseudo(String pseudo) async {
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(pseudo: pseudo));
    }
  }
}

class FakeCategoryNotifier extends CategoryNotifier {
  @override
  void build() {}

  final List<List<String>> addedToUser = [];
  final List<String> createdNames = [];

  @override
  Future<void> addCategoriesToUser(List<String> categoryIds) async {
    addedToUser.add(categoryIds);
  }

  @override
  Future<void> createAndAddCategory(String name, int icon) async {
    createdNames.add(name);
  }
}

class FakeBookScannerNotifier extends BookScannerNotifier {
  final BookScannerState? _initialState;

  FakeBookScannerNotifier({this._initialState});

  @override
  BookScannerState build() => _initialState ?? BookScannerState();

  final List<BookModel> savedBooks = [];
  // Réglé par les tests : champ public voulu sur ce faux notifier.
  // ignore: riverpod_lint/avoid_public_notifier_properties
  BookModel? bookToReturnOnScan;

  @override
  void startListening(String uid) {
    state = state.copyWith(isLoading: false);
  }

  @override
  Future<BookModel?> scanIsbn(String isbn) async {
    state = state.copyWith(isScanning: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (ref.mounted) {
      state = state.copyWith(
        isScanning: false,
        scannedBook: bookToReturnOnScan,
      );
    }
    return bookToReturnOnScan;
  }

  @override
  Future<void> saveBook(BookModel book) async {
    state = state.copyWith(isSaving: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    savedBooks.add(book);
    if (ref.mounted) {
      state = state.copyWith(isSaving: false);
    }
  }

  @override
  Future<void> deleteBook(String bookId) async {
    savedBooks.removeWhere((b) => b.id == bookId);
  }

  @override
  void reset() {
    state = state.copyWith(clearScannedBook: true, clearError: true);
  }
}

final defaultTestOverrides = [
  userRepositoryProvider.overrideWithValue(FakeUserRepository()),
  birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
  categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
  bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
  authProvider.overrideWith(FakeAuthNotifier.new),
  userProvider.overrideWith(FakeUserNotifier.new),
  categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
  bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
];
