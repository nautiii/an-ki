import 'dart:async';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/reminders/widgets/reminders_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_harness.dart';

/// Service dont la première lecture attend que le test réponde.
class _SlowService extends SilentNotificationService {
  final read = Completer<NotificationAccess>();

  @override
  Future<NotificationAccess> access() => read.future;
}

void main() {
  late SilentNotificationService notifications;

  Future<void> pumpTile(
    WidgetTester tester, {
    NotificationAccess access = NotificationAccess.denied,
    NotificationAccess answer = NotificationAccess.granted,
  }) async {
    notifications = SilentNotificationService(access: access, answer: answer);
    await tester.pumpHarness(
      const RemindersTile(),
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
    );
    await tester.pumpAndSettle();
  }

  /// Retour dans l'app, après la boîte système ou les réglages.
  Future<void> backToApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('allowed: tells when reminders come', (tester) async {
    await pumpTile(tester, access: NotificationAccess.granted);

    expect(find.text('Rappels'), findsOneWidget);
    expect(find.text('7 jours avant et le jour J, à 10:00'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('off: turns them on through the system box, and confirms', (
    tester,
  ) async {
    await pumpTile(tester);

    expect(
      find.text('Désactivés : AnKi ne peut pas vous prévenir.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(notifications.requests, 1);
    expect(find.text('7 jours avant et le jour J, à 10:00'), findsOneWidget);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('a refusal leaves them off, ready to ask again', (tester) async {
    await pumpTile(tester, answer: NotificationAccess.denied);

    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(find.text('Activer les rappels'), findsOneWidget);
    expect(find.text('Rappels activés'), findsNothing);
  });

  testWidgets('blocked: opens the settings, confirms once allowed there', (
    tester,
  ) async {
    await pumpTile(tester, answer: NotificationAccess.blocked);

    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bloqués dans les réglages du téléphone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ouvrir les réglages'));
    await tester.pumpAndSettle();
    expect(notifications.settingsOpened, 1);

    notifications.current = NotificationAccess.granted;
    await backToApp(tester);

    expect(find.text('7 jours avant et le jour J, à 10:00'), findsOneWidget);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('sees a change made in the settings from elsewhere', (
    tester,
  ) async {
    await pumpTile(tester);

    notifications.current = NotificationAccess.granted;
    await backToApp(tester);

    expect(find.text('7 jours avant et le jour J, à 10:00'), findsOneWidget);
    // Pas ouverts d'ici : rien à confirmer.
    expect(find.text('Rappels activés'), findsNothing);
  });

  testWidgets('shows a skeleton until the permission is read', (tester) async {
    final slow = _SlowService();
    await tester.pumpHarness(
      const RemindersTile(),
      overrides: [notificationServiceProvider.overrideWithValue(slow)],
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsOneWidget);

    slow.read.complete(NotificationAccess.granted);
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonBox), findsNothing);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(tester, answer: NotificationAccess.blocked);
    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds together on a small phone at 200 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTile(tester, answer: NotificationAccess.blocked);
    tester.view.physicalSize = const Size(360, 640);
    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ouvrir les réglages'), findsOneWidget);
  });
}
