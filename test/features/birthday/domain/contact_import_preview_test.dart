import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/contact_import_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lundi 12 octobre 2026.
  final today = DateTime(2026, 10, 12);

  BirthdayDraft contact(
    String name,
    String surname,
    int month,
    int day, {
    int? year,
  }) => BirthdayDraft(
    name: name,
    surname: surname,
    date: BirthDate(year: year, month: month, day: day),
  );

  Birthday saved(
    String name,
    String surname,
    int month,
    int day, {
    int? year,
  }) => Birthday(
    id: '$name$surname',
    name: name,
    surname: surname,
    date: BirthDate(year: year, month: month, day: day),
  );

  List<String> names(List<BirthdayDraft> drafts) => [
    for (final draft in drafts) draft.fullName,
  ];

  test('lists contacts from the soonest birthday, then by name', () {
    final preview = previewContactImport(
      [
        contact('Zoé', 'Lambert', 3, 1),
        contact('Hugo', 'Bernard', 10, 15),
        contact('Léa', 'Martin', 10, 12),
        contact('Alice', 'Roux', 10, 15),
      ],
      existing: const [],
      today: today,
    );

    expect(names(preview.fresh), [
      'Léa Martin',
      'Alice Roux',
      'Hugo Bernard',
      'Zoé Lambert',
    ]);
    expect(preview.known, isEmpty);
  });

  test('sets apart whoever AnKi already has, year or not', () {
    final preview = previewContactImport(
      [
        // Même personne, sans l'année, et écrite autrement.
        contact('lea', 'MARTIN', 3, 12),
        contact('Jean-Pierre', 'Dupont', 5, 2, year: 1960),
        contact('Hugo', 'Bernard', 6, 1, year: 1985),
      ],
      existing: [
        saved('Léa', 'Martin', 3, 12, year: 1990),
        saved('Jean', 'Pierre  Dupont', 5, 2),
        // Même nom, autre jour : une autre personne.
        saved('Hugo', 'Bernard', 6, 2),
      ],
      today: today,
    );

    expect(names(preview.known), ['lea MARTIN', 'Jean-Pierre Dupont']);
    expect(names(preview.fresh), ['Hugo Bernard']);
  });

  test('proposes a person twice in the contacts only once', () {
    final preview = previewContactImport(
      [
        contact('Léa', 'Martin', 3, 12, year: 1990),
        contact('Léa', 'Martin', 3, 12),
      ],
      existing: const [],
      today: today,
    );

    expect(preview.fresh, [contact('Léa', 'Martin', 3, 12, year: 1990)]);
  });

  test('names a contact by its last name, skips one without any name', () {
    final preview = previewContactImport(
      [
        contact(' ', 'Dupont', 1, 5),
        contact('', '', 2, 6),
        contact(' Mamie ', '', 4, 7),
      ],
      existing: const [],
      today: today,
    );

    expect(preview.fresh, [
      contact('Dupont', '', 1, 5),
      contact('Mamie', '', 4, 7),
    ]);
  });

  test('is empty without contacts', () {
    expect(
      previewContactImport(const [], existing: const [], today: today),
      const ContactImportPreview(fresh: [], known: []),
    );
  });

  test('compares previews by value', () {
    final a = ContactImportPreview(
      fresh: [contact('Léa', 'Martin', 3, 12)],
      known: const [],
    );
    final b = ContactImportPreview(
      fresh: [contact('Léa', 'Martin', 3, 12)],
      known: const [],
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
