import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 1);
  const work = BirthdayCategory(id: 'wor', name: 'colleague', icon: 1);
  const other = BirthdayCategory(id: 'oth', name: 'other', icon: 1);
  const goat = BirthdayCategory(id: 'goat', name: 'goat', icon: 1);
  const sport = BirthdayCategory(id: 'spo', name: 'sport', icon: 1);
  const book = BirthdayCategory(id: 'book', name: 'Club de lecture', icon: 1);
  const climbing = BirthdayCategory(id: 'cli', name: 'Écalade', icon: 1);

  group('userGroups', () {
    test('offers the four defaults to everyone, « Autres » last', () {
      expect(userGroups(shared: [other, sport, work, friend, family]), [
        family,
        friend,
        work,
        other,
      ]);
    });

    test('puts the picked and private groups between, by name', () {
      expect(
        userGroups(
          shared: [family, friend, work, other, goat, sport],
          pickedIds: ['goat'],
          own: [climbing, book],
        ),
        // « Écalade » se range à la lettre e, accent ignoré.
        [family, friend, work, book, climbing, goat, other],
      );
    });

    test('lists a group once, even picked as a default', () {
      expect(userGroups(shared: [family, other], pickedIds: ['fam', 'oth']), [
        family,
        other,
      ]);
    });

    test('omits a default not loaded yet', () {
      expect(userGroups(shared: const [], own: [book]), [book]);
    });

    test('takes the first of two categories sharing a default name', () {
      const twin = BirthdayCategory(id: 'fam2', name: 'Family', icon: 2);

      expect(userGroups(shared: [family, twin]), [family]);
    });
  });

  group('firstFreeTone', () {
    const palette = [0, 1, 2, 4];

    test('takes the first tone nobody has', () {
      expect(firstFreeTone([0, 1, 14], palette), 2);
      expect(firstFreeTone(const [], palette), 0);
    });

    test('starts the palette again once every tone is taken', () {
      expect(firstFreeTone([0, 1, 2, 4], palette), 0);
      expect(firstFreeTone([0, 1, 2, 4, 0], palette), 1);
    });
  });

  group('groupNameIssue', () {
    const existing = ['Famille', 'Amis', 'Club de lecture'];

    test('an empty or blank name is refused', () {
      expect(groupNameIssue('', existing), GroupNameIssue.empty);
      expect(groupNameIssue('   ', existing), GroupNameIssue.empty);
    });

    test('a name already used is taken, case and accents aside', () {
      expect(groupNameIssue('famille', existing), GroupNameIssue.taken);
      expect(groupNameIssue(' AMÏS ', existing), GroupNameIssue.taken);
      expect(groupNameIssue('club de lecture', existing), GroupNameIssue.taken);
    });

    test('a new name is fine', () {
      expect(groupNameIssue('Voisins', existing), isNull);
    });
  });
}
