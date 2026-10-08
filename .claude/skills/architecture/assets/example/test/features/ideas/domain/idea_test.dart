import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 3, 12);
  final idea = Idea(
    id: 'i1',
    title: 'Livre',
    personId: 'p1',
    note: 'Poche',
    createdAt: createdAt,
  );

  group('Idea', () {
    test('copyWith keeps unspecified fields and changes the given ones', () {
      final copy = idea.copyWith(title: 'Vinyle');

      expect(copy.title, 'Vinyle');
      expect(copy.personId, 'p1');
      expect(copy.note, 'Poche');
      expect(copy.createdAt, createdAt);
    });

    test('copyWith clears optional fields only when asked', () {
      expect(idea.copyWith(clearNote: true).note, isNull);
      expect(idea.copyWith(clearPersonId: true).personId, isNull);
    });

    test('compares by value', () {
      expect(idea, idea.copyWith());
      expect(idea.hashCode, idea.copyWith().hashCode);
      expect(idea, isNot(idea.copyWith(title: 'Autre')));
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
      final older = idea.copyWith(title: 'Ancienne');
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
