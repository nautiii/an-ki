import 'dart:async';

import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';

/// Service dont la demande attend que le test réponde.
class _PendingRequestService extends SilentNotificationService {
  _PendingRequestService() : super(access: NotificationAccess.denied);

  final answered = Completer<NotificationAccess>();

  @override
  Future<NotificationAccess> requestAccess() {
    requests++;
    return answered.future;
  }
}

void main() {
  ProviderContainer makeContainer(SilentNotificationService notifications) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
    );
    container.listen(reminderPermissionProvider, (_, _) {});
    return container;
  }

  test('reads the permission without asking', () async {
    final notifications = SilentNotificationService(
      access: NotificationAccess.denied,
    );
    final container = makeContainer(notifications);

    expect(
      await container.read(reminderPermissionProvider.future),
      NotificationAccess.denied,
    );
    expect(notifications.requests, 0);
  });

  test('a request publishes its answer and returns it', () async {
    final notifications = SilentNotificationService(
      access: NotificationAccess.denied,
    );
    final container = makeContainer(notifications);
    await container.read(reminderPermissionProvider.future);

    final access = await container
        .read(reminderPermissionProvider.notifier)
        .request();

    expect(access, NotificationAccess.granted);
    expect(
      container.read(reminderPermissionProvider).value,
      NotificationAccess.granted,
    );
  });

  test('loads during a request, keeping what it knew, and ignores a second '
      'one', () async {
    final notifications = _PendingRequestService();
    final container = makeContainer(notifications);
    await container.read(reminderPermissionProvider.future);
    final permission = container.read(reminderPermissionProvider.notifier);

    final first = permission.request();
    final state = container.read(reminderPermissionProvider);
    expect(state.isLoading, isTrue);
    expect(state.value, NotificationAccess.denied);
    expect(await permission.request(), NotificationAccess.denied);
    expect(notifications.requests, 1);

    notifications.answered.complete(NotificationAccess.blocked);
    expect(await first, NotificationAccess.blocked);
    expect(
      container.read(reminderPermissionProvider),
      const AsyncData(NotificationAccess.blocked),
    );
  });

  test('a refresh keeps a known block, the reading cannot see it', () async {
    final notifications = SilentNotificationService(
      access: NotificationAccess.denied,
      answer: NotificationAccess.blocked,
    );
    final container = makeContainer(notifications);
    await container.read(reminderPermissionProvider.future);
    final permission = container.read(reminderPermissionProvider.notifier);
    await permission.request();

    expect(await permission.refresh(), NotificationAccess.blocked);
    expect(
      container.read(reminderPermissionProvider).value,
      NotificationAccess.blocked,
    );
  });

  test('a refresh sees notifications allowed in the settings', () async {
    final notifications = SilentNotificationService(
      access: NotificationAccess.denied,
      answer: NotificationAccess.blocked,
    );
    final container = makeContainer(notifications);
    await container.read(reminderPermissionProvider.future);
    final permission = container.read(reminderPermissionProvider.notifier);
    await permission.request();

    notifications.current = NotificationAccess.granted;

    expect(await permission.refresh(), NotificationAccess.granted);
    expect(
      container.read(reminderPermissionProvider).value,
      NotificationAccess.granted,
    );
  });

  test('a refresh leaves a request in progress alone', () async {
    final notifications = _PendingRequestService();
    final container = makeContainer(notifications);
    await container.read(reminderPermissionProvider.future);
    final permission = container.read(reminderPermissionProvider.notifier);

    unawaited(permission.request());

    expect(await permission.refresh(), NotificationAccess.denied);
    expect(container.read(reminderPermissionProvider).isLoading, isTrue);
    notifications.answered.complete(NotificationAccess.granted);
  });

  test('opens the notification settings', () async {
    final notifications = SilentNotificationService();
    final container = makeContainer(notifications);

    await container.read(reminderPermissionProvider.notifier).openSettings();

    expect(notifications.settingsOpened, 1);
  });
}
