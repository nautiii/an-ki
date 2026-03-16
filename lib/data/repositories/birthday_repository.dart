import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/birthday_model.dart';

class BirthdayRepository {
  Stream<List<BirthdayModel>> watchBirthdays() {
    return FirebaseFirestore.instance
        .collection('birthday')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => BirthdayModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // DateTime nextBirthday(DateTime birthDate) {
  //   final now = DateTime.now();
  //
  //   DateTime next = DateTime(now.year, birthDate.month, birthDate.day);
  //
  //   if (next.isBefore(now)) {
  //     next = DateTime(now.year + 1, birthDate.month, birthDate.day);
  //   }
  //
  //   return next;
  // }
  // birthdays.sort((a, b) =>
  // nextBirthday(a.date).compareTo(nextBirthday(b.date)));
}
