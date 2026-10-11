import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  group('Header', () {
    testWidgets('shows the user name and reports toggle and settings taps', (
      tester,
    ) async {
      var toggles = 0;
      var settingsOpened = 0;

      await tester.pumpHarness(
        Header(
          userName: 'Q',
          onToggleView: () => toggles++,
          onOpenSettings: () => settingsOpened++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.text('Q'), findsOneWidget);

      await tester.tap(find.byTooltip('Afficher le calendrier'));
      await tester.pumpAndSettle();
      expect(toggles, 1);

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      expect(settingsOpened, 1);
    });

    testWidgets('shows the list icon while in calendar view', (tester) async {
      await tester.pumpHarness(
        Header(userName: 'Q', isListView: false, onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.byTooltip('Afficher la liste'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
    });

    testWidgets('shows a skeleton while the name loads and hides the toggle', (
      tester,
    ) async {
      await tester.pumpHarness(
        Header(userName: null, showViewToggle: false, onOpenSettings: () {}),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
      expect(find.byIcon(Icons.view_list_rounded), findsNothing);
    });

    testWidgets('labels its buttons for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(
        Header(userName: 'Q', onToggleView: () {}, onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('SearchBarWidget', () {
    testWidgets('reports changes and triggers add', (tester) async {
      final queries = <String>[];
      var addPressed = 0;

      await tester.pumpHarness(
        SearchBarWidget(
          onSearchChanged: queries.add,
          onAddPressed: () => addPressed++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      expect(queries.last, 'Alice');

      await tester.tap(find.byTooltip('Ajouter un anniversaire'));
      expect(addPressed, 1);
    });

    testWidgets('shows a clear button as soon as there is text', (
      tester,
    ) async {
      final queries = <String>[];

      await tester.pumpHarness(SearchBarWidget(onSearchChanged: queries.add));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Effacer la recherche'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      expect(find.byTooltip('Effacer la recherche'), findsOneWidget);

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pump();

      expect(queries.last, '');
      expect(find.widgetWithText(TextField, 'Alice'), findsNothing);
      expect(find.byTooltip('Effacer la recherche'), findsNothing);
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(
        SearchBarWidget(onSearchChanged: (_) {}, onAddPressed: () {}),
      );
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();

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

      expect(find.text('Birthdays'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
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

  group('AnKiFadeIn', () {
    testWidgets('renders its child immediately when there is no delay', (
      tester,
    ) async {
      await tester.pumpHarness(const AnKiFadeIn(child: Text('Visible')));
      await tester.pumpAndSettle();

      expect(find.text('Visible'), findsOneWidget);
    });

    testWidgets('renders its child after a delay', (tester) async {
      await tester.pumpHarness(
        const AnKiFadeIn(
          delay: Duration(milliseconds: 100),
          child: Text('Delayed'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Delayed'), findsOneWidget);
    });
  });
}
