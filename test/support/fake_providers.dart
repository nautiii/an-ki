import 'dart:async';

import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/foundation.dart';

class FakeUserProvider extends ChangeNotifier implements UserProvider {
  FakeUserProvider({
    UserModel? initialUser,
    this.defaultLoadedUser = const UserModel(
      id: 'default-user',
      name: 'Quentin',
      surname: 'Maillard',
    ),
  }) : _user = initialUser;

  final UserModel? defaultLoadedUser;
  Completer<UserModel?>? _pendingLoad;
  UserModel? _user;
  bool _isLoading = false;

  String? receivedName;
  String? receivedSurname;

  @override
  UserModel? get user => _user;

  @override
  set user(UserModel? value) {
    _user = value;
  }

  @override
  bool get isLoading => _isLoading;

  void preparePendingLoad() {
    _pendingLoad = Completer<UserModel?>();
  }

  void completePendingLoad([UserModel? user]) {
    final Completer<UserModel?>? completer = _pendingLoad;

    if (completer != null && !completer.isCompleted) {
      completer.complete(user);
    }
  }

  @override
  Future<void> loadUser({required String name, required String surname}) async {
    receivedName = name;
    receivedSurname = surname;

    final Completer<UserModel?>? completer = _pendingLoad;
    if (completer == null) {
      _user = defaultLoadedUser;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _user = await completer.future;

    _isLoading = false;
    notifyListeners();
  }
}

class FakeBirthdayProvider extends ChangeNotifier implements BirthdayProvider {
  FakeBirthdayProvider({
    List<BirthdayModel> initialBirthdays = const <BirthdayModel>[],
    bool isLoading = false,
  }) : _birthdays = List<BirthdayModel>.from(initialBirthdays),
       _isLoading = isLoading;

  final List<CreateBirthdayInput> createdInputs = <CreateBirthdayInput>[];

  List<BirthdayModel> _birthdays;
  bool _isLoading;
  bool _isCreating = false;

  @override
  List<BirthdayModel> get birthdays => _birthdays;

  @override
  set birthdays(List<BirthdayModel> value) {
    _birthdays = value;
    notifyListeners();
  }

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  bool get isCreating => _isCreating;

  @override
  set isCreating(bool value) {
    _isCreating = value;
    notifyListeners();
  }

  @override
  BirthdayRepository get repository => throw UnimplementedError();

  @override
  Future<void> createBirthday(CreateBirthdayInput input) async {
    if (_isCreating) {
      return;
    }

    _isCreating = true;
    notifyListeners();

    createdInputs.add(input);
    await Future<void>.value();

    _isCreating = false;
    notifyListeners();
  }

  @override
  Future<void> updateBirthday(String birthdayId, CreateBirthdayInput input) async {
    if (_isCreating) {
      return;
    }

    _isCreating = true;
    notifyListeners();

    createdInputs.add(input);
    await Future<void>.value();

    _isCreating = false;
    notifyListeners();
  }
}
