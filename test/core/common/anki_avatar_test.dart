import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  test('initials keep at most two words, uppercased', () {
    expect(AnKiAvatar.initialsOf('Léa Martin'), 'LM');
    expect(AnKiAvatar.initialsOf('  élodie   de la Tour '), 'ÉD');
    expect(AnKiAvatar.initialsOf('Mamie'), 'M');
    expect(AnKiAvatar.initialsOf('   '), '');
  });

  testWidgets('shows the initials when there is no photo', (tester) async {
    await tester.pumpHarness(const AnKiAvatar(name: 'Léa Martin'));

    expect(find.text('LM'), findsOneWidget);
  });

  testWidgets('falls back to an icon for an empty name', (tester) async {
    await tester.pumpHarness(const AnKiAvatar(name: ''));

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('the same name always gets the same tone', (tester) async {
    await tester.pumpHarness(
      const Column(
        children: [
          AnKiAvatar(name: 'Léa Martin'),
          AnKiAvatar(name: 'Léa Martin'),
        ],
      ),
    );

    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();
    expect(avatars.first.backgroundColor, avatars.last.backgroundColor);
  });
}
