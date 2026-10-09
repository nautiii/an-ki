import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

BirthdayModel _born(DateTime date, {String id = 'lea'}) =>
    BirthdayModel(id: id, name: 'Léa', surname: 'Martin', date: date);

/// Rappel de [kind] dans le plan d'un seul anniversaire.
PlannedReminder _reminder(
  BirthdayModel birthday,
  ReminderKind kind, {
  required DateTime now,
}) => planReminders([birthday], now: now).singleWhere((r) => r.kind == kind);

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
}
