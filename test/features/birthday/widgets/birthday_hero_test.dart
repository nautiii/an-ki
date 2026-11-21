import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_hero.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/blossom_rain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/haptics.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le 12 mars 2026.
  final today = DateTime(2026, 3, 12);
  const onColor = Color(0xFF400012);

  /// Alice, née en 1990 (année inconnue sans [yearKnown]), le jour
  /// [daysAhead] jours après aujourd'hui (négatif : avant).
  Birthday alice(int daysAhead, {bool yearKnown = true, int year = 1990}) {
    final target = today.add(Duration(days: daysAhead));
    return Birthday(
      id: 'alice',
      name: 'Alice',
      surname: 'Wonderland',
      date: BirthDate(
        year: yearKnown ? year : null,
        month: target.month,
        day: target.day,
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpHarness(
    Center(child: SizedBox(width: 360, child: child)),
    overrides: [clockProvider.overrideWithValue(() => today)],
  );

  group('HeroSurface', () {
    testWidgets('no petals before the day', (tester) async {
      await pump(
        tester,
        HeroSurface(
          birthday: alice(3),
          celebrating: false,
          child: const Text('carte'),
        ),
      );

      expect(find.text('carte'), findsOneWidget);
      expect(find.byType(BlossomRain), findsNothing);
    });

    testWidgets('one rain on the day, none once this person had theirs', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pump(
        tester,
        HeroSurface(
          birthday: alice(0),
          celebrating: true,
          child: const Text('carte'),
        ),
      );
      await tester.pump();

      expect(find.byType(BlossomRain), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HeroSurface)),
      );
      expect(container.read(celebratedTodayProvider), {'alice'});
      await tester.pumpAndSettle();
      expect(
        tester.widget<BlossomRain>(find.byType(BlossomRain)).play,
        isFalse,
      );
    });
  });

  group('HeroDayIdentity', () {
    testWidgets('the day itself, the age in big', (tester) async {
      await pump(
        tester,
        HeroDayIdentity(
          birthday: alice(0),
          today: today,
          onColor: onColor,
          wished: false,
        ),
      );

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(find.text("fête ses 36 ans aujourd'hui"), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.byType(WishedPill), findsNothing);
    });

    testWidgets('born today: the sentence, no « 0 »', (tester) async {
      await pump(
        tester,
        HeroDayIdentity(
          birthday: alice(0, year: 2026),
          today: today,
          onColor: onColor,
          wished: false,
        ),
      );

      expect(find.text("fête son anniversaire aujourd'hui"), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('the day after: « Hier », the age reached, then « Souhaité »', (
      tester,
    ) async {
      await pump(
        tester,
        HeroDayIdentity(
          birthday: alice(-1),
          today: today,
          onColor: onColor,
          wished: true,
          dayAfter: true,
        ),
      );

      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('a eu 36 ans'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.byType(WishedPill), findsOneWidget);
    });

    testWidgets('born yesterday: the date, no « 0 »', (tester) async {
      await pump(
        tester,
        HeroDayIdentity(
          birthday: alice(-1, year: 2026),
          today: today,
          onColor: onColor,
          wished: false,
          dayAfter: true,
        ),
      );

      expect(find.text('11 mars 2026'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.textContaining('a eu'), findsNothing);
    });

    testWidgets('the day after without a birth year: the date', (tester) async {
      await pump(
        tester,
        HeroDayIdentity(
          birthday: alice(-1, yearKnown: false),
          today: today,
          onColor: onColor,
          wished: false,
          dayAfter: true,
        ),
      );

      expect(find.text('11 mars'), findsOneWidget);
      expect(find.text('ans'), findsNothing);
    });

    testWidgets('prominent: a larger avatar and the name as a header', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        MergeSemantics(
          child: HeroDayIdentity(
            birthday: alice(0),
            today: today,
            onColor: onColor,
            wished: false,
            prominent: true,
          ),
        ),
      );

      expect(tester.widget<AnKiAvatar>(find.byType(AnKiAvatar)).radius, 28);
      expect(
        tester.getSemantics(find.byType(MergeSemantics)),
        isSemantics(
          label: "Aujourd'hui 🎉\nAlice Wonderland\nfête ses 36\u00a0ans aujourd'hui",
          isHeader: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('HeroComingIdentity', () {
    testWidgets('on the home: the days above the name, the day and month', (
      tester,
    ) async {
      await pump(
        tester,
        HeroComingIdentity(birthday: alice(12), today: today, onColor: onColor),
      );

      expect(find.text('Dans 12 jours'), findsOneWidget);
      expect(find.text('24 mars'), findsOneWidget);
      expect(
        tester.widget<OrbitCountdown>(find.byType(OrbitCountdown)).diameter,
        72,
      );
    });

    testWidgets('prominent: the full date, a larger orbit, a header', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        MergeSemantics(
          child: HeroComingIdentity(
            birthday: alice(12),
            today: today,
            onColor: onColor,
            prominent: true,
          ),
        ),
      );

      expect(find.text('24 mars 1990'), findsOneWidget);
      expect(
        tester.widget<OrbitCountdown>(find.byType(OrbitCountdown)).diameter,
        80,
      );
      // Sous le MergeSemantics de l'en-tête : un nœud, lu dans l'ordre.
      expect(
        tester.getSemantics(find.byType(MergeSemantics)),
        isSemantics(
          label:
              'Dans 12 jours\nAlice Wonderland\n24 mars 1990\nAura 36\u00a0ans',
          isHeader: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('prominent without a birth year: the days said once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        HeroComingIdentity(
          birthday: alice(12, yearKnown: false),
          today: today,
          onColor: onColor,
          prominent: true,
        ),
      );

      expect(find.text('Dans 12 jours'), findsNothing);
      expect(find.bySemanticsLabel('Dans 12 jours'), findsOneWidget);
      semantics.dispose();
    });
  });
}
