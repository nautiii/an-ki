import 'package:an_ki/features/birthday/domain/guest_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guestBackupOffer', () {
    test('offers a guest to save from three birthdays', () {
      expect(guestBackupOffer(guest: true, birthdays: 3), 3);
      expect(guestBackupOffer(guest: true, birthdays: 12), 12);
    });

    test('waits until the agenda is worth keeping', () {
      expect(guestBackupOffer(guest: true, birthdays: 0), isNull);
      expect(guestBackupOffer(guest: true, birthdays: 2), isNull);
    });

    test('never offers an account that is already saved', () {
      expect(guestBackupOffer(guest: false, birthdays: 12), isNull);
    });
  });
}
