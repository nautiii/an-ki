import 'dart:async';

import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
import 'package:flutter/material.dart';

class BirthdayProvider extends ChangeNotifier {
  final BirthdayRepository repository = BirthdayRepository();

  StreamSubscription<List<BirthdayModel>>? _subscription;
  List<BirthdayModel> birthdays = [];
  bool isLoading = true;
  bool isCreating = false;

  BirthdayProvider() {
    _listenBirthdays();
  }

  void _listenBirthdays() {
    _subscription = repository.watchBirthdays().listen(
      (List<BirthdayModel> data) {
        birthdays = data;
        isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> createBirthday(CreateBirthdayInput input) async {
    if (isCreating) {
      return;
    }

    isCreating = true;
    notifyListeners();

    try {
      await repository.createBirthday(input);
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
