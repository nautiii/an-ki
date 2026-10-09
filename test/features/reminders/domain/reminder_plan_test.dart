import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _born(DateTime date, {String id = 'lea'}) =>
    Birthday(id: id, name: 'Léa', surname: 'Martin', date: date);

/// Rappel de [kind] dans le plan d'un seul anniversaire.
PlannedReminder _reminder(
  Birthday birthday,
  ReminderKind kind, {
  required DateTime now,
}) => planReminders([birthday], now: now).singleWhere((r) => r.kind == kind);

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
Birthday _person(String id) =>
    Birthday(id: id, name: id, surname: 'Martin', date: DateTime(1990, 6, 30));

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
            .singleWhere((r) => r.name == id && r.kind == ReminderKind.birthday)
            .id,
        plan
            .singleWhere(
              (r) => r.name == id && r.kind == ReminderKind.weekBefore,
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

    expect(plan.map((r) => r.kind), [
      ReminderKind.birthday,
      ReminderKind.weekBefore,
      ReminderKind.birthday,
      ReminderKind.weekBefore,
    ]);
    expect(planReminders(const [], now: now), isEmpty);
  });

  test('reminds at 10:00 on the day and seven days before', () {
    final birthday = _born(DateTime(1990, 6, 30));

    final day = _reminder(birthday, ReminderKind.birthday, now: now);
    final weekBefore = _reminder(birthday, ReminderKind.weekBefore, now: now);

    expect(day.at, DateTime(2026, 6, 30, 10));
    expect(day.age, 36);
    expect(weekBefore.at, DateTime(2026, 6, 23, 10));
    expect(weekBefore.age, 36);
  });

  test('keeps a birthday today when 10:00 is still ahead', () {
    final birthday = _born(DateTime(1990, 6, 15));

    final day = _reminder(birthday, ReminderKind.birthday, now: now);

    expect(day.at, DateTime(2026, 6, 15, 10));
    expect(day.age, 36);
  });

  test('moves a slot already past to next year', () {
    final birthday = _born(DateTime(1990, 6, 15));
    final afterTen = DateTime(2026, 6, 15, 11);

    final day = _reminder(birthday, ReminderKind.birthday, now: afterTen);
    final weekBefore = _reminder(
      birthday,
      ReminderKind.weekBefore,
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
      ReminderKind.weekBefore,
      now: DateTime(2026, 3, 20),
    );

    expect(weekBefore.at, DateTime(2026, 3, 26, 10));
  });

  test('reminds a 29 February birthday on 1 March in common years', () {
    final birthday = _born(DateTime(2000, 2, 29));

    final day = _reminder(
      birthday,
      ReminderKind.birthday,
      now: DateTime(2027, 1, 10),
    );

    expect(day.at, DateTime(2027, 3, 1, 10));
    expect(day.age, 27);
  });

  test('derives stable ids, distinct per kind', () {
    final birthday = _born(DateTime(1990, 6, 30));
    final base = 'lea'.hashCode.abs() % 100000;

    final ids = planReminders([birthday], now: now).map((r) => r.id);

    expect(ids, [base, base + 500000]);
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
}
