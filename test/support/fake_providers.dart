import 'dart:async';

import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book_model.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
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
  Stream<UserModel?> watchUser(String uid) => Stream.value(null);

  @override
  Future<UserModel> createUser(UserModel user) async => user;

  @override
  Future<void> updatePreferences(
    String uid, {
    String? pseudo,
    bool? isDark,
    String? locale,
  }) async {}

  @override
  Future<void> addCategories(String uid, List<String> categoryIds) async {}

  @override
  Future<void> deleteUser(String uid) async {}
}

/// Dépôt de profils en mémoire : [watchUser] reflète chaque écriture, comme
/// le cache local de Firestore, pour tester les écritures optimistes.
class RecordingUserRepository extends FakeUserRepository {
  RecordingUserRepository({this._stored, this.failure});

  UserModel? _stored;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final _changes = StreamController<UserModel?>.broadcast();
  final created = <UserModel>[];
  final updated = <UserModel>[];
  final deleted = <String>[];

  UserModel? get stored => _stored;

  @override
  Stream<UserModel?> watchUser(String uid) {
    // Abonnement immédiat : aucune écriture n'est perdue entre deux émissions.
    final controller = StreamController<UserModel?>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_stored);
    return controller.stream;
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    _maybeFail();
    created.add(user);
    // Comme le vrai « créer si absent » : le profil existant gagne.
    final effective = _stored ?? user;
    _emit(effective);
    return effective;
  }

  @override
  Future<void> updatePreferences(
    String uid, {
    String? pseudo,
    bool? isDark,
    String? locale,
  }) async {
    _maybeFail();
    final user = _stored!.copyWith(
      pseudo: pseudo,
      isDark: isDark,
      locale: locale,
    );
    updated.add(user);
    _emit(user);
  }

  @override
  Future<void> addCategories(String uid, List<String> categoryIds) async {
    _maybeFail();
    final user = _stored!.copyWith(
      categories: {..._stored!.categories, ...categoryIds}.toList(),
    );
    updated.add(user);
    _emit(user);
  }

  @override
  Future<void> deleteUser(String uid) async {
    _maybeFail();
    deleted.add(uid);
    _emit(null);
  }

  void _emit(UserModel? user) {
    _stored = user;
    _changes.add(user);
  }

  void _maybeFail() {
    if (failure case final failure?) throw failure;
  }
}

class FakeBirthdayRepository extends Fake implements BirthdayRepository {
  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) => Stream.value([]);

  @override
  Future<void> createBirthday(String uid, BirthdayDraft draft) async {}

  @override
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) async {}

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
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
  final created = <BirthdayDraft>[];
  final updated = <String>[];
  final deleted = <String>[];
  final erasedUids = <String>[];

  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) {
    watchedUids.add(uid);
    return Stream.value(initial);
  }

  @override
  Future<void> createBirthday(String uid, BirthdayDraft draft) async {
    _maybeFail();
    created.add(draft);
  }

  @override
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) async {
    _maybeFail();
    created.addAll(drafts);
  }

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) async {
    _maybeFail();
    updated.add(birthdayId);
    created.add(draft);
  }

  @override
  Future<void> deleteBirthday(String birthdayId) async {
    _maybeFail();
    deleted.add(birthdayId);
  }

  @override
  Future<void> deleteAllUserBirthdays(String uid) async {
    _maybeFail();
    erasedUids.add(uid);
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
  Future<void> saveBook(
    String uid,
    BookModel book, {
    required DateTime scannedAt,
  }) async {}

  @override
  Future<void> deleteBook(String bookId) async {}
}

/// Dépôt de livres configurable qui enregistre les écritures.
class RecordingBookRepository extends FakeBookRepository {
  RecordingBookRepository({
    this.bookByIsbn,
    this.throwOnScan,
    this.books = const [],
    this.failure,
  });

  final BookModel? bookByIsbn;
  final Exception? throwOnScan;

  /// Livres servis par [watchBooks].
  final List<BookModel> books;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final watchedUids = <String>[];
  final saved = <BookModel>[];

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    if (throwOnScan case final error?) throw error;
    return bookByIsbn;
  }

  @override
  Stream<List<BookModel>> watchBooks(String uid) {
    watchedUids.add(uid);
    return Stream.value(books);
  }

  /// Livres enregistrés, datés comme ils le seraient dans Firestore.
  @override
  Future<void> saveBook(
    String uid,
    BookModel book, {
    required DateTime scannedAt,
  }) async {
    if (failure case final error?) throw error;
    saved.add(book.copyWith(scannedAt: scannedAt));
  }
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

final defaultTestOverrides = [
  userRepositoryProvider.overrideWithValue(FakeUserRepository()),
  birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
  categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
  bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
  authProvider.overrideWith(FakeAuthNotifier.new),
  categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
];
