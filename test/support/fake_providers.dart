import 'dart:async';

import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'fake-uid';
  @override
  String? get displayName => 'Fake User';
  @override
  bool get isAnonymous => false;
}

class FakeUserRepository extends UserRepository {
  @override
  Future<UserModel?> fetchUser(String uid) async => null;
  @override
  Future<void> createUser(UserModel user) async {}
  @override
  Future<void> updateUser(UserModel user) async {}
}

class FakeBirthdayRepository extends BirthdayRepository {
  @override
  Stream<List<BirthdayModel>> watchBirthdays(String uid) => Stream.value([]);
  @override
  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {}
  @override
  Future<void> updateBirthday(String uid, String birthdayId, CreateBirthdayInput input) async {}
}

class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({AuthState? initialState}) : super(firebaseAuth: null, googleSignIn: null) {
    if (initialState != null) state = initialState;
  }

  @override
  void initializeAuth() {
    // Do nothing to avoid accessing Firebase in tests
  }

  void updateState(AuthState newState) {
    state = newState;
  }

  @override
  Future<void> signOut() async {
    state = AuthState();
  }

  @override
  Future<bool> signIn({required String email, required String password}) async {
    return true;
  }

  @override
  Future<bool> signInAnonymously() async {
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    return true;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    return true;
  }

  @override
  Future<bool> linkWithGoogle() async {
    return true;
  }
}

class FakeUserProvider extends UserProvider {
  FakeUserProvider({
    UserModel? initialUser,
    this.defaultLoadedUser = const UserModel(
      id: 'default-user',
      name: 'Quentin',
      surname: 'Maillard',
    ),
  }) : super(FakeUserRepository()) {
    state = UserState(user: initialUser);
  }

  final UserModel? defaultLoadedUser;
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
    state = state.copyWith(user: UserModel(id: uid, name: name, surname: surname));
  }
}

class FakeBirthdayProvider extends BirthdayProvider {
  FakeBirthdayProvider({
    List<BirthdayModel> initialBirthdays = const [],
    bool isLoading = false,
  }) : super(FakeBirthdayRepository()) {
    state = BirthdayState(birthdays: initialBirthdays, isLoading: isLoading);
  }

  final List<CreateBirthdayInput> createdInputs = [];

  @override
  void startListening(String uid) {
    state = state.copyWith(isLoading: false);
  }

  @override
  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {
    state = state.copyWith(isCreating: true);
    createdInputs.add(input);
    await Future.value();
    state = state.copyWith(isCreating: false);
  }

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async {
    state = state.copyWith(isCreating: true);
    createdInputs.add(input);
    await Future.value();
    state = state.copyWith(isCreating: false);
  }

  @override
  void clear() {
    state = BirthdayState();
  }
}
