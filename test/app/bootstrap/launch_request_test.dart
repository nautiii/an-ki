import 'package:an_ki/app/bootstrap/launch_request.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LaunchRequest.fromNotification', () {
    test('« Souhaiter » wishes, the notification itself opens the page', () {
      expect(
        LaunchRequest.fromNotification(
          const NotificationTap(
            payload: 'lea',
            actionId: NotificationActions.wish,
          ),
        ),
        const WishLaunch('lea'),
      );
      expect(
        LaunchRequest.fromNotification(const NotificationTap(payload: 'lea')),
        const PersonLaunch('lea'),
      );
    });

    test('a tap naming no birthday asks nothing', () {
      expect(
        LaunchRequest.fromNotification(
          const NotificationTap(
            payload: null,
            actionId: NotificationActions.wish,
          ),
        ),
        isNull,
      );
    });

    test('a wish and a page of the same person differ', () {
      expect(const WishLaunch('lea'), isNot(const PersonLaunch('lea')));
      expect(
        const WishLaunch('lea').hashCode,
        const WishLaunch('lea').hashCode,
      );
    });
  });

  test('a launcher shortcut asks for its module shortcut', () {
    expect(LaunchRequest.fromShortcut('add'), const ShortcutLaunch('add'));
    expect(const ShortcutLaunch('add'), isNot(const ShortcutLaunch('scan')));
  });

  test('« Souhaiter à … » asks to wish its birthday', () {
    expect(
      LaunchRequest.fromShortcut(wishShortcutType('lea')),
      const WishLaunch('lea'),
    );
    expect(wishShortcutType('lea'), 'wish:lea');
  });
}
