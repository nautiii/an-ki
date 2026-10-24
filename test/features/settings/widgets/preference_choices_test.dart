import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/settings/widgets/preference_choices.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Camille',
  surname: 'Durand',
  theme: ThemePreference.dark,
  locale: 'fr',
);

void main() {
  /// Un profil chargé, dont le dépôt reflète chaque écriture.
  List<Object> overridesWith(RecordingUserRepository users) => [
    userRepositoryProvider.overrideWithValue(users),
    currentUidProvider.overrideWithValue('uid-1'),
  ];

  Set<ThemePreference> selectedTheme(WidgetTester tester) => tester
      .widget<SegmentedButton<ThemePreference>>(
        find.byType(SegmentedButton<ThemePreference>),
      )
      .selected;

  group('ThemeChoice', () {
    testWidgets('shows the profile choice among the three themes', (
      tester,
    ) async {
      final users = RecordingUserRepository(stored: _profile);
      await tester.pumpHarness(
        const ThemeChoice(),
        overrides: overridesWith(users),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thème'), findsOneWidget);
      expect(find.text('Système'), findsOneWidget);
      expect(find.text('Clair'), findsOneWidget);
      expect(find.text('Sombre'), findsOneWidget);
      expect(selectedTheme(tester), {ThemePreference.dark});
    });

    testWidgets('writes the picked theme and shows it at once', (tester) async {
      final users = RecordingUserRepository(stored: _profile);
      await tester.pumpHarness(
        const ThemeChoice(),
        overrides: overridesWith(users),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Système'));
      await tester.pumpAndSettle();

      expect(users.stored?.theme, ThemePreference.system);
      expect(selectedTheme(tester), {ThemePreference.system});
    });

    testWidgets('follows the system until the profile is loaded', (
      tester,
    ) async {
      await tester.pumpHarness(
        const ThemeChoice(),
        overrides: overridesWith(RecordingUserRepository()),
      );
      await tester.pumpAndSettle();

      expect(selectedTheme(tester), {ThemePreference.system});
    });

    testWidgets('keeps 48 dp targets', (tester) async {
      await tester.pumpHarness(
        const ThemeChoice(),
        overrides: overridesWith(RecordingUserRepository(stored: _profile)),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('lays the segments side by side when the labels fit', (
      tester,
    ) async {
      await tester.pumpHarness(
        const ThemeChoice(),
        overrides: overridesWith(RecordingUserRepository(stored: _profile)),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<ThemePreference>>(
              find.byType(SegmentedButton<ThemePreference>),
            )
            .direction,
        Axis.horizontal,
      );
    });

    testWidgets('stacks the segments rather than cut a label', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpHarness(
        const Center(child: SizedBox(width: 320, child: ThemeChoice())),
        overrides: overridesWith(RecordingUserRepository(stored: _profile)),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<ThemePreference>>(
              find.byType(SegmentedButton<ThemePreference>),
            )
            .direction,
        Axis.vertical,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('LanguageChoice', () {
    testWidgets('names each language in itself and writes the pick', (
      tester,
    ) async {
      final users = RecordingUserRepository(stored: _profile);
      await tester.pumpHarness(
        const LanguageChoice(),
        overrides: overridesWith(users),
      );
      await tester.pumpAndSettle();

      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'fr'},
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(users.stored?.locale, 'en');
    });
  });
}
