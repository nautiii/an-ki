import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:an_ki/features/reminders/providers/reminders_off_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_providers.dart';

void main() {
  const lea = Birthday(
    id: '1',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(month: 3, day: 12),
  );

  /// Conteneur où l'autorisation vaut [access], l'agenda [birthdays] et le
  /// masquage ce que disent [settings] ; attend les lectures asynchrones.
  Future<ProviderContainer> makeContainer({
    NotificationAccess access = NotificationAccess.denied,
    List<Birthday> birthdays = const [lea],
    FakeDeviceSettings? settings,
  }) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        notificationServiceProvider.overrideWithValue(
          SilentNotificationService(access: access),
        ),
        birthdaysListProvider.overrideWithValue(birthdays),
        deviceSettingsProvider.overrideWithValue(
          settings ?? FakeDeviceSettings(),
        ),
      ],
    );
    container.listen(remindersOffNoticeProvider, (_, _) {});
    await container.read(reminderPermissionProvider.future);
    await container.read(remindersOffDismissalProvider.future);
    return container;
  }

  group('remindersOffNoticeProvider', () {
    test('says refused reminders when the agenda has someone', () async {
      final container = await makeContainer();

      expect(
        container.read(remindersOffNoticeProvider),
        NotificationAccess.denied,
      );
    });

    test('says blocked reminders, which only the settings fix', () async {
      final container = await makeContainer(access: NotificationAccess.blocked);

      expect(
        container.read(remindersOffNoticeProvider),
        NotificationAccess.blocked,
      );
    });

    test('says nothing once reminders are granted', () async {
      final container = await makeContainer(access: NotificationAccess.granted);

      expect(container.read(remindersOffNoticeProvider), isNull);
    });

    test('says nothing while the agenda is empty', () async {
      final container = await makeContainer(birthdays: const []);

      expect(container.read(remindersOffNoticeProvider), isNull);
    });

    test('says nothing on a phone where the card was dismissed', () async {
      final container = await makeContainer(
        settings: FakeDeviceSettings(remindersOffDismissedValue: true),
      );

      expect(container.read(remindersOffNoticeProvider), isNull);
    });
  });

  group('RemindersOffDismissal', () {
    test('hides the card at once and remembers it', () async {
      final settings = FakeDeviceSettings();
      final container = await makeContainer(settings: settings);

      await container.read(remindersOffDismissalProvider.notifier).dismiss();

      expect(container.read(remindersOffNoticeProvider), isNull);
      expect(settings.remindersOffDismissedValue, isTrue);
    });

    test('keeps it hidden for the session when saving fails', () async {
      final settings = FakeDeviceSettings(failure: Exception('keystore'));
      final container = await makeContainer(settings: settings);

      await container.read(remindersOffDismissalProvider.notifier).dismiss();

      expect(settings.dismissals, 1);
      expect(container.read(remindersOffNoticeProvider), isNull);
    });
  });
}
