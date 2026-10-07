import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

/// Mirrors how `HomeScreen` rebuilds its subtree when the search query changes,
/// which is what makes the [SearchBarWidget] clear button appear.
class _RebuildingSearchHost extends StatefulWidget {
  const _RebuildingSearchHost({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_RebuildingSearchHost> createState() => _RebuildingSearchHostState();
}

class _RebuildingSearchHostState extends State<_RebuildingSearchHost> {
  @override
  Widget build(BuildContext context) {
    return SearchBarWidget(
      onSearchChanged: (value) {
        widget.onChanged(value);
        setState(() {});
      },
    );
  }
}

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

      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await tester.pumpAndSettle();
      expect(toggles, 1);

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
      expect(settingsOpened, 1);
    });

    testWidgets('shows the list icon while in calendar view', (tester) async {
      await tester.pumpHarness(
        Header(userName: 'Q', isListView: false, onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
    });

    testWidgets('shows a placeholder and hides the view toggle', (
      tester,
    ) async {
      await tester.pumpHarness(
        Header(userName: null, showViewToggle: false, onOpenSettings: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('...'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
      expect(find.byIcon(Icons.view_list_rounded), findsNothing);
    });
  });

  group('SearchBarWidget', () {
    testWidgets('reports changes, shows a clear button and triggers add', (
      tester,
    ) async {
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

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(addPressed, 1);
    });

    testWidgets(
      'clear button appears on a parent rebuild and resets the text',
      (tester) async {
        final queries = <String>[];

        await tester.pumpHarness(_RebuildingSearchHost(onChanged: queries.add));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Alice');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.clear), findsOneWidget);

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(queries.last, '');
        expect(find.byIcon(Icons.clear), findsNothing);
      },
    );
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
    testWidgets('switches the active tab', (tester) async {
      await tester.pumpHarness(const BottomBar());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BottomBar)),
      );

      expect(container.read(navigationProvider), MainTab.birthdays);

      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
      await tester.pumpAndSettle();

      expect(container.read(navigationProvider), MainTab.scanner);

      // Tapping the already-selected tab is a no-op.
      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
      await tester.pumpAndSettle();
      expect(container.read(navigationProvider), MainTab.scanner);

      // Switch back to the birthdays tab.
      await tester.tap(find.byIcon(Icons.cake_outlined));
      await tester.pumpAndSettle();
      expect(container.read(navigationProvider), MainTab.birthdays);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: BottomBar()),
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
