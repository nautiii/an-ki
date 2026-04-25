import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? user;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> loadUser(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      user = await _repository.fetchUser(uid);
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'utilisateur: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUser({
    required String uid,
    required String name,
    required String surname,
  }) async {
    final newUser = UserModel(id: uid, name: name, surname: surname);
    await _repository.createUser(newUser);
    user = newUser;
    notifyListeners();
  }

  void clear() {
    user = null;
    _isLoading = false;
    notifyListeners();
  }
}
