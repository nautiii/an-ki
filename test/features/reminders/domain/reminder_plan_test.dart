import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _born(DateTime date, {String id = 'lea'}) => Birthday(
  id: id,
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate.fromDate(date),
);

/// Rappel de [lead] dans le plan d'un seul anniversaire.
PlannedReminder _reminder(
  Birthday birthday,
  ReminderLead lead, {
  required DateTime now,
  ReminderPreferences preferences = const ReminderPreferences(),
}) => planReminders(
  [birthday],
  now: now,
  preferences: preferences,
).singleWhere((r) => r.lead == lead);

/// Emplacement naturel d'un id d'anniversaire (formule historique).
int _slot(String id) => id.hashCode.abs() % 100000;

/// Deux ids d'anniversaire distincts qui visent le même emplacement, triés.
(String, String) _collidingIds() {
  final seen = <int, String>{};
  for (var i = 0; ; i++) {
    final id = 'birthday-$i';
    final other = seen[_slot(id)];
    if (other != null) {
      return other.compareTo(id) < 0 ? (other, id) : (id, other);
    }
    seen[_slot(id)] = id;
  }
}

/// Un id d'anniversaire dont l'emplacement naturel est [slot].
String _idAt(int slot, {required String prefix}) {
  for (var i = 0; ; i++) {
    final id = '$prefix-$i';
    if (_slot(id) == slot) return id;
  }
}

/// Anniversaire dont le prénom reprend l'id, pour retrouver ses rappels.
Birthday _person(String id) => Birthday(
  id: id,
  name: id,
  surname: 'Martin',
  date: BirthDate.fromDate(DateTime(1990, 6, 30)),
);

/// Ids [jour J, J-7] planifiés pour chaque anniversaire, par id.
Map<String, List<int>> _idsOf(
  Iterable<String> birthdayIds, {
  required DateTime now,
}) {
  final plan = planReminders(birthdayIds.map(_person), now: now);
  return {
    for (final id in birthdayIds)
      id: [
        plan
            .singleWhere((r) => r.name == id && r.lead == ReminderLead.sameDay)
            .id,
        plan
            .singleWhere(
              (r) => r.name == id && r.lead == ReminderLead.weekBefore,
            )
            .id,
      ],
  };
}

void main() {
  // Un lundi à 9 h, avant le créneau de 10 h.
  final now = DateTime(2026, 6, 15, 9);

  test('plans the day itself and a week before for each birthday', () {
    final plan = planReminders([
      _born(DateTime(1990, 6, 30)),
      _born(DateTime(1985, 8), id: 'hugo'),
    ], now: now);

    expect(plan.map((r) => r.lead), [
      ReminderLead.weekBefore,
      ReminderLead.sameDay,
      ReminderLead.weekBefore,
      ReminderLead.sameDay,
    ]);
    // Chaque rappel ramène à son anniversaire.
    expect(plan.map((r) => r.birthdayId), ['lea', 'lea', 'hugo', 'hugo']);
    expect(planReminders(const [], now: now), isEmpty);
  });

  test('reminds at 10:00 on the day and seven days before', () {
    final birthday = _born(DateTime(1990, 6, 30));

    final day = _reminder(birthday, ReminderLead.sameDay, now: now);
    final weekBefore = _reminder(birthday, ReminderLead.weekBefore, now: now);

    expect(day.at, DateTime(2026, 6, 30, 10));
    expect(day.age, 36);
    expect(weekBefore.at, DateTime(2026, 6, 23, 10));
    expect(weekBefore.age, 36);
  });

  test('keeps a birthday today when 10:00 is still ahead', () {
    final birthday = _born(DateTime(1990, 6, 15));

    final day = _reminder(birthday, ReminderLead.sameDay, now: now);

    expect(day.at, DateTime(2026, 6, 15, 10));
    expect(day.age, 36);
  });

  test('moves a slot already past to next year', () {
    final birthday = _born(DateTime(1990, 6, 15));
    final afterTen = DateTime(2026, 6, 15, 11);

    final day = _reminder(birthday, ReminderLead.sameDay, now: afterTen);
    final weekBefore = _reminder(
      birthday,
      ReminderLead.weekBefore,
      now: afterTen,
    );

    expect(day.at, DateTime(2027, 6, 15, 10));
    expect(day.age, 37);
    expect(weekBefore.at, DateTime(2027, 6, 8, 10));
    expect(weekBefore.age, 37);
  });

  test('counts the week before in calendar days across a DST change', () {
    // Passage à l'heure d'été fin mars en Europe : sept tranches de 24 h
    // tomberaient la veille au soir.
    final birthday = _born(DateTime(1990, 4, 2));

    final weekBefore = _reminder(
      birthday,
      ReminderLead.weekBefore,
      now: DateTime(2026, 3, 20),
    );

    expect(weekBefore.at, DateTime(2026, 3, 26, 10));
  });

  test('reminds a 29 February birthday on 1 March in common years', () {
    final birthday = _born(DateTime(2000, 2, 29));

    final day = _reminder(
      birthday,
      ReminderLead.sameDay,
      now: DateTime(2027, 1, 10),
    );

    expect(day.at, DateTime(2027, 3, 1, 10));
    expect(day.age, 27);
  });

  test('reminds without an age when the birth year is unknown', () {
    const birthday = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate(month: 6, day: 30),
    );

    final day = _reminder(birthday, ReminderLead.sameDay, now: now);
    final weekBefore = _reminder(birthday, ReminderLead.weekBefore, now: now);

    expect(day.at, DateTime(2026, 6, 30, 10));
    expect(day.age, isNull);
    expect(weekBefore.at, DateTime(2026, 6, 23, 10));
    expect(weekBefore.age, isNull);
  });

  test('derives stable ids, distinct per lead', () {
    final birthday = _born(DateTime(1990, 6, 30));
    final base = 'lea'.hashCode.abs() % 100000;

    final ids = planReminders([birthday], now: now).map((r) => r.id);

    expect(ids, [base + 500000, base]);
    expect(planReminders([birthday], now: now).map((r) => r.id), ids);
  });

  group('notification ids', () {
    test('give colliding birthdays both reminders under distinct ids', () {
      final (first, second) = _collidingIds();
      final slot = _slot(first);

      final ids = _idsOf([first, second], now: now);

      // Le plus petit id garde l'emplacement, l'autre prend le suivant.
      expect(ids[first], [slot, slot + 500000]);
      final next = (slot + 1) % 100000;
      expect(ids[second], [next, next + 500000]);
      expect(ids.values.expand((i) => i).toSet(), hasLength(4));
    });

    test('do not depend on the order of the birthdays', () {
      final (first, second) = _collidingIds();

      expect(
        _idsOf([second, first], now: now),
        _idsOf([first, second], now: now),
      );
    });

    test('keep the historic id of a birthday that owns its slot', () {
      final (first, second) = _collidingIds();
      final slot = _slot(first);
      // Un troisième anniversaire vise l'emplacement où sonderait le perdant.
      final neighbour = _idAt((slot + 1) % 100000, prefix: 'neighbour');

      final ids = _idsOf([first, second, neighbour], now: now);

      expect(ids[neighbour]![0], _slot(neighbour));
      expect(ids[first]![0], slot);
      expect(ids[second]![0], (slot + 2) % 100000);
    });

    test('wrap around past the last slot', () {
      final first = _idAt(99999, prefix: 'a');
      final second = _idAt(99999, prefix: 'b');

      final ids = _idsOf([first, second], now: now);

      expect(ids[first], [99999, 599999]);
      expect(ids[second], [0, 500000]);
    });

    test('share one slot between duplicates of the same birthday', () {
      final plan = planReminders([_born(now), _born(now)], now: now);

      expect(plan.map((r) => r.id).toSet(), hasLength(2));
    });
  });

  group('nextBirthdayReminder', () {
    final now = DateTime(2026, 10, 19, 9);

    Birthday person(String id, String name, DateTime date) => Birthday(
      id: id,
      name: name,
      surname: '',
      date: BirthDate.fromDate(date),
    );

    test('is the first reminder of the day itself to come', () {
      final next = nextBirthdayReminder([
        person('a', 'Louis', DateTime(1980, 12, 2)),
        person('b', 'Hugo', DateTime(1992, 10, 21)),
        // Son rappel d'une semaine avant (le 20) passe avant le jour J de
        // Hugo : il ne compte pas.
        person('c', 'Chloé', DateTime(2018, 10, 27)),
      ], now: now)!;

      expect(next.lead, ReminderLead.sameDay);
      expect(next.name, 'Hugo');
      expect(next.at, DateTime(2026, 10, 21, 10));
    });

    test('keeps today while 10:00 is still ahead, then moves on', () {
      final birthdays = [
        person('a', 'Léa', DateTime(1990, 10, 19)),
        person('b', 'Hugo', DateTime(1992, 10, 21)),
      ];

      expect(nextBirthdayReminder(birthdays, now: now)!.name, 'Léa');
      expect(
        nextBirthdayReminder(birthdays, now: DateTime(2026, 10, 19, 11))!.name,
        'Hugo',
      );
    });

    test('breaks a tie by name', () {
      final day = DateTime(1990, 11, 6);
      final next = nextBirthdayReminder([
        person('a', 'Sarah', day),
        person('b', 'Nathan', day),
      ], now: now);

      expect(next!.name, 'Nathan');
    });

    test('is null without any birthday', () {
      expect(nextBirthdayReminder(const [], now: now), isNull);
    });
  });

  group('preferences', () {
    const early = ReminderPreferences(
      leads: {ReminderLead.monthBefore, ReminderLead.dayBefore},
      hour: 8,
      minute: 30,
    );

    test('plans the chosen leads at the chosen time, and always the day', () {
      final birthday = _born(DateTime(1990, 6, 30));

      final plan = planReminders(
        [birthday],
        now: DateTime(2026, 5),
        preferences: early,
      );

      expect(plan.map((r) => (r.lead, r.at)), [
        (ReminderLead.monthBefore, DateTime(2026, 5, 31, 8, 30)),
        (ReminderLead.dayBefore, DateTime(2026, 6, 29, 8, 30)),
        (ReminderLead.sameDay, DateTime(2026, 6, 30, 8, 30)),
      ]);
    });

    test('moves a month-before slot already past to next year', () {
      final birthday = _born(DateTime(1990, 6, 30));

      final monthBefore = _reminder(
        birthday,
        ReminderLead.monthBefore,
        now: DateTime(2026, 6, 10),
        preferences: early,
      );

      expect(monthBefore.at, DateTime(2027, 5, 31, 8, 30));
      expect(monthBefore.age, 37);
    });

    test('gives each lead its own id range', () {
      const all = ReminderPreferences(leads: {...ReminderLead.values});
      final base = 'lea'.hashCode.abs() % 100000;

      final plan = planReminders(
        [_born(DateTime(1990, 6, 30))],
        now: now,
        preferences: all,
      );

      expect(plan.map((r) => r.id), [
        base + 200000,
        base + 500000,
        base + 100000,
        base,
      ]);
    });

    test('follows the own setting of a person over the default one', () {
      Birthday withReminders(String id, Set<ReminderLead>? reminders) =>
          Birthday(
            id: id,
            name: id,
            surname: '',
            date: BirthDate.fromDate(DateTime(1990, 6, 30)),
            reminders: reminders,
          );

      final plan = planReminders([
        withReminders('usual', null),
        withReminders('none', const {}),
        // Le jour J s'ajoute même s'il manque au réglage.
        withReminders('custom', const {ReminderLead.dayBefore}),
      ], now: now);

      List<ReminderLead> leadsOf(String name) => [
        for (final r in plan)
          if (r.name == name) r.lead,
      ];
      expect(leadsOf('usual'), [ReminderLead.weekBefore, ReminderLead.sameDay]);
      expect(leadsOf('none'), isEmpty);
      expect(leadsOf('custom'), [ReminderLead.dayBefore, ReminderLead.sameDay]);
    });

    test('names the earliest lead before the day', () {
      expect(early.earliestLead, ReminderLead.monthBefore);
      expect(const ReminderPreferences().earliestLead, ReminderLead.weekBefore);
      expect(
        const ReminderPreferences(leads: {ReminderLead.sameDay}).earliestLead,
        isNull,
      );
    });
  });

  test('keeps the days themselves first past the alarm limit', () {
    const all = ReminderPreferences(leads: {...ReminderLead.values});
    final birthdays = [
      for (var i = 0; i < 300; i++)
        Birthday(
          id: 'b$i',
          name: 'b$i',
          surname: '',
          date: BirthDate.fromDate(DateTime(1990, 1 + i % 12, 1 + i % 28)),
        ),
    ];

    final plan = planReminders(birthdays, now: now, preferences: all);

    expect(plan, hasLength(ReminderPolicy.maxScheduled));
    expect(plan.where((r) => r.lead == ReminderLead.sameDay), hasLength(300));
    // Puis les rappels d'une semaine avant, les plus proches d'abord.
    final weekBefore = plan.where((r) => r.lead == ReminderLead.weekBefore);
    expect(weekBefore, hasLength(ReminderPolicy.maxScheduled - 300));
    final kept = weekBefore.map((r) => r.at).toList();
    expect(kept, [...kept]..sort());
  });

  test('names the person as the notification does', () {
    final reminders = planReminders([
      _born(DateTime(1990, 6, 30)),
      Birthday(
        id: 'mamie',
        name: 'Mamie',
        surname: '',
        date: BirthDate.fromDate(DateTime(1940, 6, 30)),
      ),
    ], now: DateTime(2026, 3));

    expect(reminders.map((r) => r.fullName).toSet(), {'Léa Martin', 'Mamie'});
  });
}
