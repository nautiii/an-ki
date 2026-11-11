import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 8);

NextVolumeInfo _info({
  int number = 109,
  ReleaseStatus status = ReleaseStatus.announced,
  ReleaseDate? date,
  ReleaseSource source = ReleaseSource.bnf,
}) => NextVolumeInfo(
  number: number,
  status: status,
  date: date,
  source: source,
  checkedAt: DateTime(2026, 11, 8),
);

/// One Piece avec les tomes 1 à [last], sauf ceux de [missing].
ShelfEntry _entry({
  NextVolumeInfo? next,
  bool complete = false,
  int last = 108,
  List<int> missing = const [],
}) => shelfOf(
  [
    Series(
      id: 'op',
      name: 'One Piece',
      keys: const ['one piece'],
      complete: complete,
      next: next,
    ),
  ],
  [
    for (var n = 1; n <= last; n++)
      if (!missing.contains(n))
        Volume(
          id: '$n',
          seriesId: 'op',
          number: n,
          title: 'T$n',
          authors: const [],
          lookup: LookupState.found,
          addedAt: DateTime(2026),
        ),
  ],
).entries.single;

void main() {
  late ShelfWords words;

  Future<void> french(WidgetTester tester) async {
    final context = await tester.pumpLocalizedContext();
    words = ShelfWords(AppLocalizations.of(context), 'fr');
  }

  group('nextLine', () {
    testWidgets('an announced day this year has no year', (tester) async {
      await french(tester);
      final entry = _entry(
        next: _info(date: const ReleaseDate(year: 2026, month: 12, day: 3)),
      );

      expect(words.nextLine(entry, _today), 'Prochain : tome 109 · 3 décembre');
    });

    testWidgets('an announced day another year carries the year', (
      tester,
    ) async {
      await french(tester);
      final entry = _entry(
        next: _info(date: const ReleaseDate(year: 2027, month: 12, day: 3)),
      );

      expect(
        words.nextLine(entry, _today),
        'Prochain : tome 109 · 3 décembre 2027',
      );
    });

    testWidgets('a month only is said with its year', (tester) async {
      await french(tester);
      final entry = _entry(
        next: _info(date: const ReleaseDate(year: 2027, month: 10)),
      );

      expect(
        words.nextLine(entry, _today),
        'Prochain : tome 109 · octobre 2027',
      );
    });

    testWidgets('a released volume is said so', (tester) async {
      await french(tester);
      final entry = _entry(next: _info(status: ReleaseStatus.released));

      expect(words.nextLine(entry, _today), 'Prochain : tome 109 · paru');
    });

    testWidgets('an unknown date is never replaced by a date', (tester) async {
      await french(tester);

      for (final entry in [
        _entry(),
        _entry(next: _info()),
        _entry(next: _info(status: ReleaseStatus.unknown)),
      ]) {
        final line = words.nextLine(entry, _today);
        expect(line, 'Prochain : tome 109 · date inconnue');
        expect(line, isNot(contains('20')));
      }
    });

    testWidgets('a complete series says so', (tester) async {
      await french(tester);

      expect(words.nextLine(_entry(complete: true), _today), 'Série terminée');
    });
  });

  group('holesLine', () {
    testWidgets('lists up to five holes', (tester) async {
      await french(tester);

      expect(words.holesLine([13, 14]), 'Il vous manque 13, 14');
      expect(words.holesLine([1, 2, 3, 4, 5]), 'Il vous manque 1, 2, 3, 4, 5');
    });

    testWidgets('counts the others beyond five', (tester) async {
      await french(tester);

      expect(
        words.holesLine([1, 2, 3, 4, 5, 6, 7, 8, 9]),
        'Il vous manque 1, 2, 3, 4, 5 et 4 autres',
      );
      expect(
        words.holesLine([1, 2, 3, 4, 5, 6]),
        'Il vous manque 1, 2, 3, 4, 5 et 1 autre',
      );
    });

    testWidgets('is null without a hole', (tester) async {
      await french(tester);

      expect(words.holesLine(const []), isNull);
    });
  });

  group('seriesLabel', () {
    testWidgets('reads the row in screen order', (tester) async {
      await french(tester);
      final entry = _entry(
        missing: [13, 14],
        next: _info(date: const ReleaseDate(year: 2026, month: 12, day: 3)),
      );

      expect(
        words.seriesLabel(entry, _today),
        'One Piece, dernier tome 108, prochain tome 109, sortie le 3 décembre, '
        'il vous manque les tomes 13 et 14',
      );
    });

    testWidgets('says a single hole in the singular', (tester) async {
      await french(tester);
      final entry = _entry(missing: [13]);

      expect(
        words.seriesLabel(entry, _today),
        'One Piece, dernier tome 108, prochain tome 109, date inconnue, '
        'il vous manque le tome 13',
      );
    });

    testWidgets('names the first five holes and counts the others', (
      tester,
    ) async {
      await french(tester);
      final entry = _entry(missing: [1, 2, 3, 4, 5, 6, 7, 8]);

      expect(
        words.seriesLabel(entry, _today),
        'One Piece, dernier tome 108, prochain tome 109, date inconnue, '
        'il vous manque les tomes 1, 2, 3, 4, 5 et 3 autres',
      );
    });

    testWidgets('an empty series has no volume', (tester) async {
      await french(tester);

      expect(
        words.seriesLabel(_entry(last: 0), _today),
        'One Piece, aucun tome, prochain tome 1, date inconnue',
      );
    });

    testWidgets('covers the month, released and complete cases', (
      tester,
    ) async {
      await french(tester);

      expect(
        words.seriesLabel(
          _entry(next: _info(date: const ReleaseDate(year: 2027, month: 10))),
          _today,
        ),
        'One Piece, dernier tome 108, prochain tome 109, sortie en octobre 2027',
      );
      expect(
        words.seriesLabel(
          _entry(next: _info(status: ReleaseStatus.released)),
          _today,
        ),
        'One Piece, dernier tome 108, prochain tome 109, paru',
      );
      expect(
        words.seriesLabel(_entry(complete: true), _today),
        'One Piece, dernier tome 108, série terminée',
      );
    });
  });

  group('loadError', () {
    testWidgets('offline is a network message, the rest is generic', (
      tester,
    ) async {
      await french(tester);

      expect(
        words.loadError(ShelfFailure.offline),
        'Pas de connexion. Vérifiez votre réseau et réessayez.',
      );
      expect(
        words.loadError(ShelfFailure.denied),
        "Quelque chose s'est mal passé. Réessayez dans un instant.",
      );
      expect(
        words.loadError(ShelfFailure.failed),
        "Quelque chose s'est mal passé. Réessayez dans un instant.",
      );
      expect(
        words.loadError(Exception('boom')),
        "Quelque chose s'est mal passé. Réessayez dans un instant.",
      );
      expect(
        words.loadError(null),
        "Quelque chose s'est mal passé. Réessayez dans un instant.",
      );
    });
  });

  group('numberList', () {
    testWidgets('joins with commas and « et »', (tester) async {
      await french(tester);

      expect(words.numberList([13]), '13');
      expect(words.numberList([13, 14]), '13 et 14');
      expect(words.numberList([13, 14, 15]), '13, 14 et 15');
    });
  });

  group('nextCard', () {
    testWidgets('has one text per case', (tester) async {
      await french(tester);

      expect(
        words.nextCard(
          _entry(next: _info(status: ReleaseStatus.released)),
          _today,
        ),
        "Tome 109 paru · vous ne l'avez pas",
      );
      expect(
        words.nextCard(
          _entry(
            next: _info(date: const ReleaseDate(year: 2026, month: 12, day: 3)),
          ),
          _today,
        ),
        'Tome 109 · sortie le 3 décembre',
      );
      expect(
        words.nextCard(
          _entry(next: _info(date: const ReleaseDate(year: 2027, month: 10))),
          _today,
        ),
        'Tome 109 · sortie en octobre 2027',
      );
      expect(words.nextCard(_entry(), _today), 'Tome 109 · date inconnue');
      expect(
        words.nextCard(_entry(complete: true), _today),
        'Série terminée\u00a0: rien à attendre',
      );
    });
  });

  group('nextSource', () {
    testWidgets('names the source and the check day', (tester) async {
      await french(tester);
      final entry = _entry(
        next: _info(date: const ReleaseDate(year: 2026, month: 12, day: 3)),
      );

      expect(
        words.nextSource(entry, _today),
        'selon la BnF · vérifié le 8 nov.',
      );
    });

    testWidgets('names Google Books and the user entry', (tester) async {
      await french(tester);
      const date = ReleaseDate(year: 2026, month: 12, day: 3);

      expect(
        words.nextSource(
          _entry(
            next: _info(date: date, source: ReleaseSource.googleBooks),
          ),
          _today,
        ),
        'selon Google Books · vérifié le 8 nov.',
      );
      expect(
        words.nextSource(
          _entry(
            next: _info(date: date, source: ReleaseSource.user),
          ),
          _today,
        ),
        'date saisie par vous le 8 nov.',
      );
    });

    testWidgets('says when the BnF had no record', (tester) async {
      await french(tester);

      expect(
        words.nextSource(
          _entry(next: _info(status: ReleaseStatus.unknown)),
          _today,
        ),
        'rien à la BnF · vérifié le 8 nov.',
      );
      // Saisie par l'utilisateur sans date : rien à dire.
      expect(
        words.nextSource(
          _entry(
            next: _info(
              status: ReleaseStatus.unknown,
              source: ReleaseSource.user,
            ),
          ),
          _today,
        ),
        isNull,
      );
    });

    testWidgets('is null without info, for stale info or an unknown date', (
      tester,
    ) async {
      await french(tester);

      expect(words.nextSource(_entry(), _today), isNull);
      // Tome déjà possédé : l'information est périmée.
      expect(
        words.nextSource(
          _entry(
            next: _info(
              number: 50,
              date: const ReleaseDate(year: 2026, month: 12, day: 3),
            ),
          ),
          _today,
        ),
        isNull,
      );
      // Une annonce sans date n'apprend rien.
      expect(words.nextSource(_entry(next: _info()), _today), isNull);
      expect(
        words.nextSource(
          _entry(
            complete: true,
            next: _info(date: const ReleaseDate(year: 2026, month: 12, day: 3)),
          ),
          _today,
        ),
        isNull,
      );
    });
  });

  group('volumeTitle', () {
    Volume volume({String title = '', int? number, String? isbn}) => Volume(
      id: 'v',
      number: number,
      isbn: isbn,
      title: title,
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026),
    );

    testWidgets('falls back from title to number, ISBN, then unknown', (
      tester,
    ) async {
      await french(tester);

      expect(words.volumeTitle(volume(title: ' Blacksad ')), 'Blacksad');
      expect(words.volumeTitle(volume(number: 12, isbn: '978')), 'Tome 12');
      expect(
        words.volumeTitle(volume(isbn: '9782344059562')),
        'ISBN 9782344059562',
      );
      expect(words.volumeTitle(volume()), 'Titre inconnu');
    });
  });

  group('published', () {
    testWidgets('reads a day, a month, a year, or the raw text', (
      tester,
    ) async {
      await french(tester);

      expect(words.published('2013-06-28'), 'Paru le 28 juin 2013');
      expect(words.published('2013-06'), 'Paru en juin 2013');
      expect(words.published('2013'), 'Paru en 2013');
      expect(words.published(' vers 1990 '), 'Paru en vers 1990');
    });
  });
}
