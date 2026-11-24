import 'package:an_ki/core/extensions/focus_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  testWidgets('dismissKeyboard takes the focus off the field', (tester) async {
    await tester.pumpHarness(const TextField());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final node = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    expect(node.hasFocus, isTrue);

    tester.element(find.byType(TextField)).dismissKeyboard();
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });

  testWidgets('without a focused field, it does nothing', (tester) async {
    await tester.pumpHarness(const Text('Étagère'));

    tester.element(find.text('Étagère')).dismissKeyboard();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
