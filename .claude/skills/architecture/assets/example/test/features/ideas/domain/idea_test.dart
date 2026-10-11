import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 3, 12);

  /// Idée de référence ; chaque argument en change un champ.
  Idea idea({String title = 'Livre'}) => Idea(
    id: 'i1',
    title: title,
    personId: 'p1',
    note: 'Poche',
    createdAt: createdAt,
  );

  group('Idea', () {
    test('compares by value', () {
      expect(idea(), idea());
      expect(idea().hashCode, idea().hashCode);
      expect(idea(), isNot(idea(title: 'Autre')));
    });
  });

  group('IdeaDraft', () {
    test('is valid with a trimmed, non-empty title', () {
      const draft = IdeaDraft(title: '  Livre  ');

      expect(draft.isValid, isTrue);
      expect(draft.normalizedTitle, 'Livre');
    });

    test('is invalid when blank or too long', () {
      expect(const IdeaDraft(title: '   ').isValid, isFalse);
      expect(
        IdeaDraft(title: 'x' * (IdeaDraft.maxTitleLength + 1)).isValid,
        isFalse,
      );
    });
  });

  group('IdeaQueries.forPerson', () {
    test('keeps the ideas of one person, newest first', () {
      final older = idea(title: 'Ancienne');
      final newer = Idea(
        id: 'i2',
        title: 'Récente',
        personId: 'p1',
        createdAt: createdAt.add(const Duration(days: 1)),
      );
      final unassigned = Idea(id: 'i3', title: 'À trier', createdAt: createdAt);

      expect([older, unassigned, newer].forPerson('p1'), [newer, older]);
      expect([older, unassigned, newer].forPerson(null), [unassigned]);
    });
  });
}
