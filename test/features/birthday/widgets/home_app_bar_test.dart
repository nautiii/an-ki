import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:an_ki/features/birthday/widgets/home_app_bar.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  /// La barre seule, au-dessus d'une liste vide, saluée le jour.
  Future<void> pumpBar(WidgetTester tester, {required String? name}) async {
    await tester.pumpHarness(
      const CustomScrollView(slivers: [HomeAppBar(canSearch: true)]),
      overrides: [
        greetingProvider.overrideWithValue(Greeting.day),
        greetingNameProvider.overrideWithValue(name),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Le texte s'affiche en entier, sans « … ».
  void expectWhole(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width),
    );
  }

  testWidgets('greets on one line when it fits', (tester) async {
    await pumpBar(tester, name: 'Camille');

    expect(find.text('Bonjour, Camille'), findsOneWidget);
    expectWhole(tester, 'Bonjour, Camille');
  });

  testWidgets('puts a long name under the greeting rather than cutting it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpBar(tester, name: 'Marie-Charlotte Dupont');

    expect(find.text('Bonjour, Marie-Charlotte Dupont'), findsNothing);
    expect(find.text('Bonjour'), findsOneWidget);
    expectWhole(tester, 'Marie-Charlotte Dupont');
    // TalkBack lit toujours une seule salutation.
    expect(
      find.bySemanticsLabel('Bonjour, Marie-Charlotte Dupont'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('makes room for both lines with large text on a phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpBar(tester, name: 'Léa');
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(AppBar));
    expect(
      tester.getRect(find.text('Bonjour')).top,
      greaterThanOrEqualTo(bar.top),
    );
    expect(
      tester.getRect(find.text('Léa')).bottom,
      lessThanOrEqualTo(bar.bottom),
    );
    expectWhole(tester, 'Léa');
  });

  testWidgets('keeps the standard height at the normal text size', (
    tester,
  ) async {
    await pumpBar(tester, name: 'Camille');

    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  testWidgets('greets a guest without a name', (tester) async {
    await pumpBar(tester, name: null);

    expect(find.text('Bonjour'), findsOneWidget);
  });
}
