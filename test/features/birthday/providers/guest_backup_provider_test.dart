import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/guest_backup_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Session de [guest] dont l'agenda compte [count] anniversaires.
  ProviderContainer makeContainer({required bool guest, required int count}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        isGuestProvider.overrideWithValue(guest),
        birthdaysProvider.overrideWithValue(
          AsyncData([
            for (var i = 1; i <= count; i++)
              Birthday(
                id: 'b$i',
                name: 'Ami $i',
                surname: '',
                date: BirthDate(month: 1, day: i),
              ),
          ]),
        ),
      ],
    );
    container.listen(guestBackupOfferProvider, (_, _) {});
    return container;
  }

  int? offerFor({required bool guest, required int count}) =>
      makeContainer(guest: guest, count: count).read(guestBackupOfferProvider);

  test('a guest with three birthdays is offered to save them', () {
    expect(offerFor(guest: true, count: 3), 3);
  });

  test('a guest with fewer birthdays is left alone', () {
    expect(offerFor(guest: true, count: 2), isNull);
  });

  test('a saved account is never offered', () {
    expect(offerFor(guest: false, count: 12), isNull);
  });

  test('a birthday being deleted no longer counts', () {
    final container = makeContainer(guest: true, count: 3);

    container.read(pendingDeletionsProvider.notifier).hide('b1');

    expect(container.read(guestBackupOfferProvider), isNull);
  });
}
