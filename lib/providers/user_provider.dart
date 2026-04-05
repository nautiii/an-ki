import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? user;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> loadUser({required String name, required String surname}) async {
    _isLoading = true;
    notifyListeners();

    user = await _repository.fetchUser(name: name, surname: surname);

    _isLoading = false;
    notifyListeners();
  }
}
