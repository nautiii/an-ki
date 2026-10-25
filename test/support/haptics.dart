import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relève les vibrations demandées pendant le test, dans l'ordre
/// (`'HapticFeedbackType.lightImpact'`…).
List<Object?> recordHaptics(WidgetTester tester) {
  final haptics = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}
