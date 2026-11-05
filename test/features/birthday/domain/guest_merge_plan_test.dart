import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/guest_merge_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _person(
  String id,
  String name, {
  int month = 10,
  int day = 9,
  int? year,
  List<String> categories = const [],
}) => Birthday(
  id: id,
  name: name,
  surname: '',
  date: BirthDate(year: year, month: month, day: day),
  categories: categories,
);

BirthdayCategory _group(String id, String name) =>
    BirthdayCategory(id: id, name: name, icon: 1);

void main() {
  test('moves the guest birthdays the account does not have', () {
    final plan = planGuestMerge(
      guest: [_person('b1', 'Léa'), _person('b2', 'Tom', month: 2, day: 1)],
      guestGroups: const [],
      target: [_person('t1', 'Zoé')],
      targetGroups: const [],
    );

    expect(plan.moves, {'b1': <String>[], 'b2': <String>[]});
    expect(plan.duplicates, isEmpty);
    expect(plan.newGroups, isEmpty);
  });

  test('deletes a person the account already has, like the import', () {
    final plan = planGuestMerge(
      // Même personne : casse, accents, tiret et année n'y changent rien.
      guest: [_person('b1', 'Lea-Marie', year: 1990)],
      guestGroups: const [],
      target: [_person('t1', 'léa marie')],
      targetGroups: const [],
    );

    expect(plan.moves, isEmpty);
    expect(plan.duplicates, ['b1']);
  });

  test('keeps one of two guest records of the same person', () {
    final plan = planGuestMerge(
      guest: [_person('b1', 'Léa'), _person('b2', 'Lea')],
      guestGroups: const [],
      target: const [],
      targetGroups: const [],
    );

    expect(plan.moves.keys, ['b1']);
    expect(plan.duplicates, ['b2']);
  });

  test('joins a guest group to the account one of the same name, else '
      'recreates it', () {
    final escalade = _group('g1', 'Escalade');
    final voisins = _group('g2', 'Voisins');

    final plan = planGuestMerge(
      guest: [
        _person('b1', 'Léa', categories: ['g1', 'g2', 'family', 'gone']),
      ],
      guestGroups: [escalade, voisins],
      target: const [],
      targetGroups: [_group('t1', 'escalade ')],
    );

    // Prédéfini ou inconnu de l'invité, un groupe garde son id.
    expect(plan.moves, {
      'b1': ['t1', 'g2', 'family', 'gone'],
    });
    expect(plan.newGroups, [voisins]);
  });

  test('lists a group once when two guest groups join the same one', () {
    final plan = planGuestMerge(
      guest: [
        _person('b1', 'Léa', categories: ['g1', 'g2']),
      ],
      guestGroups: [_group('g1', 'Amis'), _group('g2', 'amis')],
      target: const [],
      targetGroups: [_group('t1', 'Amis')],
    );

    expect(plan.moves, {
      'b1': ['t1'],
    });
  });

  test('plans are equal by value', () {
    GuestMergePlan plan() => planGuestMerge(
      guest: [
        _person('b1', 'Léa', categories: ['g1']),
      ],
      guestGroups: [_group('g1', 'Amis')],
      target: const [],
      targetGroups: const [],
    );

    expect(plan(), plan());
    expect(plan().hashCode, plan().hashCode);
  });
}
