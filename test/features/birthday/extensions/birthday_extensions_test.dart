import 'package:an_ki/features/birthday/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BirthdayModel _birthday({String id = '1', required DateTime date}) {
  return BirthdayModel(
    id: id,
    uid: 'u',
    name: 'A',
    surname: 'B',
    date: date,
    categories: const [],
  );
}

/// Pumps a widget able to expose a localized [BuildContext] (French locale).
Future<BuildContext> _localizedContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('BirthdayUpcoming (date math)', () {
    test('nextOccurrence returns today when the birthday is today', () {
      final now = DateTime.now();
      final model = _birthday(date: DateTime(1990, now.month, now.day));

      expect(model.nextOccurrence, DateTime(now.year, now.month, now.day));
      expect(model.daysUntilNext, 0);
    });

    test('nextOccurrence rolls over to next year when already passed', () {
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final model = _birthday(
        date: DateTime(1990, yesterday.month, yesterday.day),
      );

      expect(model.nextOccurrence.year, now.year + 1);
      expect(model.nextOccurrence.month, yesterday.month);
      expect(model.nextOccurrence.day, yesterday.day);
      expect(model.daysUntilNext, greaterThan(0));
    });

    test('age follows the "birthday passed this year?" rule', () {
      final now = DateTime.now();

      int expectedAge(DateTime birth) {
        int years = now.year - birth.year;
        if (now.month < birth.month ||
            (now.month == birth.month && now.day < birth.day)) {
          years--;
        }
        return years;
      }

      final todayBirth = DateTime(1990, now.month, now.day);
      expect(_birthday(date: todayBirth).age, expectedAge(todayBirth));

      final future = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 40));
      final futureBirth = DateTime(1990, future.month, future.day);
      expect(_birthday(date: futureBirth).age, expectedAge(futureBirth));
    });
  });

  group('BirthdaySection.nextBirthdays', () {
    test('returns an empty list for an empty source', () {
      expect(<BirthdayModel>[].nextBirthdays, isEmpty);
    });

    test('returns the single closest upcoming birthday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final closest = _birthday(
        id: 'closest',
        date: DateTime(1990, now.month, now.day),
      );
      final far = _birthday(
        id: 'far',
        date: DateTime(
          1990,
          today.add(const Duration(days: 100)).month,
          today.add(const Duration(days: 100)).day,
        ),
      );

      final result = [far, closest].nextBirthdays;

      expect(result.map((b) => b.id), ['closest']);
    });

    test('returns every birthday that shares the closest day (tie)', () {
      final now = DateTime.now();
      final a = _birthday(id: 'a', date: DateTime(1990, now.month, now.day));
      final b = _birthday(id: 'b', date: DateTime(1970, now.month, now.day));

      final result = [a, b].nextBirthdays;

      expect(result.map((b) => b.id).toSet(), {'a', 'b'});
    });
  });

  group('BirthdayCategoryX', () {
    test('color maps known categories and falls back to grey', () {
      BirthdayCategory cat(String name) =>
          BirthdayCategory(id: '1', name: name, icon: 0);

      expect(cat('family').color, Colors.blue);
      expect(cat('FRIEND').color, Colors.green); // case-insensitive
      expect(cat('unknown').color, Colors.grey);
      expect(cat('other').color, Colors.grey);
    });

    testWidgets(
      'getLocalizedName resolves known keys and echoes custom names',
      (tester) async {
        final context = await _localizedContext(tester);
        final l10n = context.l10n;

        expect(
          BirthdayCategory(
            id: '1',
            name: 'family',
            icon: 0,
          ).getLocalizedName(context),
          l10n.family,
        );
        expect(
          BirthdayCategory(
            id: '2',
            name: 'MyCustom',
            icon: 0,
          ).getLocalizedName(context),
          'MyCustom',
        );
      },
    );
  });

  group('getFormattedDate', () {
    testWidgets('includes or omits the year', (tester) async {
      final context = await _localizedContext(tester);
      final model = _birthday(date: DateTime(1990, 1, 10));

      expect(model.getFormattedDate(context), '10 Janvier 1990');
      expect(model.getFormattedDate(context, includeYear: false), '10 Janvier');
    });
  });
}
