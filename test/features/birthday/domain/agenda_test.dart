import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _born(DateTime date, String id) => Birthday(
  id: id,
  name: 'P$id',
  surname: 'X',
  date: BirthDate.fromDate(date),
);

List<String> _ids(AgendaSection section) => [
  for (final b in section.birthdays) b.id,
];

void main() {
  final today = DateTime(2026, 10, 12);

  test('puts the next 7 days first, then one section per month', () {
    final agenda = [
      _born(DateTime(1990, 11, 26), 'nov'),
      _born(DateTime(1990, 10, 19), 'in7'),
      _born(DateTime(1990, 10, 12), 'today'),
      _born(DateTime(1990, 10, 24), 'oct'),
      _born(DateTime(1990, 10, 20), 'in8'),
    ].agenda(today);

    expect(
      [for (final s in agenda) s.period],
      [
        const AgendaSoon(),
        const AgendaMonth(2026, 10),
        const AgendaMonth(2026, 11),
      ],
    );
    expect(_ids(agenda[0]), ['today', 'in7']);
    expect(_ids(agenda[1]), ['in8', 'oct']);
    expect(_ids(agenda[2]), ['nov']);
  });

  test('skips empty months and brings the current month back next year', () {
    final agenda = [
      _born(DateTime(1990, 10), 'passed'), // 1er octobre
      _born(DateTime(1990, 1, 15), 'jan'),
    ].agenda(today);

    expect(
      [for (final s in agenda) s.period],
      [const AgendaMonth(2027, 1), const AgendaMonth(2027, 10)],
    );
  });

  test('files a 29 February birthday under March in common years', () {
    final agenda = [_born(DateTime(2000, 2, 29), 'leap')]
        .agenda(DateTime(2027, 2, 10));

    expect(agenda.single.period, const AgendaMonth(2027, 3));
  });

  test('is empty without birthdays', () {
    expect(const <Birthday>[].agenda(today), isEmpty);
  });

  test('sections and periods compare by value', () {
    final a = AgendaSection(
      period: const AgendaMonth(2026, 11),
      birthdays: [_born(DateTime(1990, 11, 2), '1')],
    );
    final b = AgendaSection(
      period: const AgendaMonth(2026, 11),
      birthdays: [_born(DateTime(1990, 11, 2), '1')],
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(const AgendaSoon(), isNot(const AgendaMonth(2026, 11)));
    expect(const AgendaSoon().hashCode, const AgendaSoon().hashCode);
  });
}
