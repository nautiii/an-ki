import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book_model.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements firebase_auth.User {
  MockUser({this.uid = 'fake-uid', this.isAnonymous = false});

  @override
  final String uid;

  @override
  String? get displayName => 'Fake User';

  @override
  final bool isAnonymous;
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
  String newCategoryId() => 'new-cat-id';

  @override
  Future<void> createCategory(BirthdayCategory category) async {}
}

/// Dépôt de catégories qui sert [categories] (ou [watchError]) et enregistre
/// les créations, avec des ids locaux prévisibles (`new-cat-1`, `new-cat-2`…).
class RecordingCategoryRepository extends Fake implements CategoryRepository {
  RecordingCategoryRepository(this.categories, {this.watchError});

  final List<BirthdayCategory> categories;

  /// Erreur émise par [watchCategories] à la place des catégories.
  final Exception? watchError;

  final created = <BirthdayCategory>[];
  var _lastId = 0;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => switch (watchError) {
    final error? => Stream.error(error),
    null => Stream.value(categories),
  };

  @override
  String newCategoryId() => 'new-cat-${++_lastId}';

  @override
  Future<void> createCategory(BirthdayCategory category) async =>
      created.add(category);
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

  @override
  Future<void> deleteAllUserBooks(String uid) async {}
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
  final erasedUids = <String>[];

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

  @override
  Future<void> deleteAllUserBooks(String uid) async {
    if (failure case final error?) throw error;
    erasedUids.add(uid);
  }
}

// --- Notifiers ---

/// Dépôt d'authentification en mémoire. La session suit les appels
/// (connexions, déconnexion, suppression) et [userChanges] la diffuse, comme
/// Firebase. [failure] fait échouer les connexions et la liaison,
/// [deleteFailure] la suppression, [tokenCheckFailure] la vérification du
/// jeton d'empreinte.
class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository({
    this._user,
    this.failure,
    this.deleteFailure,
    this.tokenCheckFailure,
  });

  firebase_auth.User? _user;
  final Exception? failure;
  final Exception? deleteFailure;
  final Exception? tokenCheckFailure;

  /// Méthodes appelées, dans l'ordre.
  final calls = <String>[];

  /// Jetons d'empreinte enregistrés sur les profils, par uid.
  final biometricTokens = <String, String?>{};

  final _changes = StreamController<firebase_auth.User?>.broadcast();

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> userChanges() {
    // Abonnement immédiat : aucun changement n'est perdu entre deux émissions.
    final controller = StreamController<firebase_auth.User?>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_user);
    return controller.stream;
  }

  @override
  Future<firebase_auth.User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _signIn('signUp', MockUser());

  @override
  Future<firebase_auth.User?> signInWithEmail({
    required String email,
    required String password,
  }) => _signIn('signInWithEmail', MockUser());

  @override
  Future<firebase_auth.User?> signInWithGoogle() =>
      _signIn('signInWithGoogle', MockUser());

  @override
  Future<firebase_auth.User?> signInAnonymously() =>
      _signIn('signInAnonymously', MockUser(isAnonymous: true));

  @override
  Future<firebase_auth.User?> linkCurrentUserWithGoogle() =>
      _signIn('linkCurrentUserWithGoogle', MockUser());

  @override
  Future<void> signOutFirebase() async {
    calls.add('signOutFirebase');
    _emit(null);
  }

  @override
  Future<void> signOutGoogle() async => calls.add('signOutGoogle');

  @override
  Future<void> deleteCurrentUser() async {
    calls.add('deleteCurrentUser');
    if (deleteFailure case final error?) throw error;
    _emit(null);
  }

  @override
  Future<void> setBiometricToken(String uid, String? token) async =>
      biometricTokens[uid] = token;

  @override
  Future<bool> isBiometricTokenValid(String uid, String token) async {
    if (tokenCheckFailure case final error?) throw error;
    return biometricTokens[uid] == token;
  }

  Future<firebase_auth.User?> _signIn(
    String call,
    firebase_auth.User user,
  ) async {
    calls.add(call);
    if (failure case final error?) throw error;
    _emit(user);
    return user;
  }

  void _emit(firebase_auth.User? user) {
    _user = user;
    _changes.add(user);
  }
}

/// Service biométrique en mémoire : capteur [available] ou non, jeton et
/// compte enregistrés sur l'appareil, empreinte acceptée si [authenticates].
class FakeBiometricService extends Fake implements BiometricService {
  FakeBiometricService({
    this.available = false,
    this.token,
    this.userId,
    this.authenticates = true,
  });

  bool available;
  String? token;
  String? userId;
  bool authenticates;

  @override
  Future<bool> canUseFingerprint() async => available;

  @override
  Future<bool> authenticate() async => authenticates;

  @override
  String generateToken() => 'generated-token';

  @override
  Future<void> saveBiometricData(String userId, String token) async {
    this.userId = userId;
    this.token = token;
  }

  @override
  Future<String?> getStoredToken() async => token;

  @override
  Future<String?> getStoredUserId() async => userId;

  @override
  Future<void> clearBiometricData() async {
    token = null;
    userId = null;
  }
}

/// Overrides du harnais : dépôts factices, personne de connecté, pas
/// d'empreinte. Une nouvelle liste (et de nouveaux faux) à chaque lecture.
List<Object> get defaultTestOverrides => [
  userRepositoryProvider.overrideWithValue(FakeUserRepository()),
  birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
  categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
  bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  biometricServiceProvider.overrideWithValue(FakeBiometricService()),
];
