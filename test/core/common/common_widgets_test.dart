import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  group('Header', () {
    testWidgets('shows the greeting and the name, opens the settings', (
      tester,
    ) async {
      var settingsOpened = 0;

      await tester.pumpHarness(
        Header(
          greeting: 'Bonsoir',
          userName: 'Q',
          onOpenSettings: () => settingsOpened++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.text('Q'), findsOneWidget);

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      expect(settingsOpened, 1);
    });

    testWidgets('shows the greeting alone without a name', (tester) async {
      await tester.pumpHarness(
        Header(greeting: 'Bonjour', userName: '', onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('shows a skeleton while the name loads', (tester) async {
      await tester.pumpHarness(
        Header(greeting: 'Bonjour', userName: null, onOpenSettings: () {}),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('labels its buttons for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(
        Header(greeting: 'Bonjour', userName: 'Q', onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('AnKiTextField', () {
    testWidgets('shows the validator error after user interaction', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpHarness(
        Form(
          child: AnKiTextField(
            controller: controller,
            label: 'Name',
            prefixIcon: Icons.person,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // 'Required' appears both in the (hidden) TextFormField error and in the
      // custom animated error label below the field.
      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('toggles focus styling when tapped', (tester) async {
      final controller = TextEditingController();
      await tester.pumpHarness(
        AnKiTextField(
          controller: controller,
          label: 'Name',
          prefixIcon: Icons.person,
          suffixIcon: const Icon(Icons.visibility),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('BottomBar', () {
    const destinations = [
      BottomBarDestination(
        icon: Icons.cake_outlined,
        selectedIcon: Icons.cake_rounded,
        label: 'Birthdays',
      ),
      BottomBarDestination(
        icon: Icons.qr_code_scanner_rounded,
        selectedIcon: Icons.qr_code_scanner_rounded,
        label: 'Scanner',
      ),
    ];

    Future<List<int>> pumpBar(WidgetTester tester, {int selected = 0}) async {
      final picked = <int>[];
      await tester.pumpHarness(
        BottomBar(
          destinations: destinations,
          selectedIndex: selected,
          onSelected: picked.add,
        ),
      );
      await tester.pumpAndSettle();
      return picked;
    }

    // Libellé coupé par des points de suspension.
    bool isCut(WidgetTester tester, String label) => tester
        .renderObject<RenderParagraph>(find.text(label))
        .didExceedMaxLines;

    // Icône au-dessus de son libellé plutôt qu'à côté.
    bool isStacked(WidgetTester tester) =>
        tester.getBottomLeft(find.byIcon(Icons.cake_rounded)).dy <=
        tester.getTopLeft(find.text('Birthdays')).dy;

    testWidgets('shows every destination with its label', (tester) async {
      await pumpBar(tester);

      expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
      expect(find.text('Birthdays'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
    });

    testWidgets('announces each destination and the selected one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester);

      expect(
        tester.getSemantics(find.text('Birthdays')),
        isSemantics(
          label: 'Birthdays',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Scanner')),
        isSemantics(label: 'Scanner', isSelected: false),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('keeps both labels whole at 200 % text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpBar(tester);

      expect(isStacked(tester), isTrue);
      expect(isCut(tester, 'Birthdays'), isFalse);
      expect(isCut(tester, 'Scanner'), isFalse);
    });

    testWidgets('puts each label beside its icon when it fits', (tester) async {
      await pumpBar(tester);

      expect(isStacked(tester), isFalse);
      expect(
        tester.getCenter(find.byIcon(Icons.cake_rounded)).dy,
        moreOrLessEquals(tester.getCenter(find.text('Birthdays')).dy),
      );
      expect(isCut(tester, 'Birthdays'), isFalse);
    });

    testWidgets('stacks the labels rather than cut one beside its icon', (
      tester,
    ) async {
      await pumpBar(tester);
      // Assez large pour « Birthdays » sous son icône, pas à côté.
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      expect(isStacked(tester), isTrue);
      expect(isCut(tester, 'Birthdays'), isFalse);
      expect(isCut(tester, 'Scanner'), isFalse);
    });

    testWidgets('reports the destination tapped', (tester) async {
      final picked = await pumpBar(tester);

      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));

      expect(picked, [1]);
    });

    testWidgets('ignores a tap on the selected destination', (tester) async {
      final picked = await pumpBar(tester, selected: 1);

      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));

      expect(picked, isEmpty);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BottomBar(
              destinations: destinations,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomBar), findsOneWidget);
    });
  });
}
