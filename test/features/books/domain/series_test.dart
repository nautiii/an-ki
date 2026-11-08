import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:flutter_test/flutter_test.dart';

NextVolumeInfo next({int number = 109, ReleaseDate? date}) => NextVolumeInfo(
  number: number,
  status: ReleaseStatus.announced,
  date: date,
  source: ReleaseSource.user,
  checkedAt: DateTime(2026, 11, 8),
);

Series series({
  String name = 'One Piece',
  List<String> keys = const ['one piece'],
  bool complete = false,
  NextVolumeInfo? info,
}) => Series(id: 's1', name: name, keys: keys, complete: complete, next: info);

void main() {
  group('Series', () {
    test('compares by value, keys included', () {
      expect(series(), series());
      expect(series().hashCode, series().hashCode);
      expect(series(), isNot(series(name: 'Naruto')));
      expect(series(), isNot(series(keys: const ['one piece', 'op'])));
      expect(series(), isNot(series(complete: true)));
      expect(series(), isNot(series(info: next())));
    });
  });

  group('NextVolumeInfo', () {
    test('compares by value', () {
      const date = ReleaseDate(year: 2026, month: 12);

      expect(next(date: date), next(date: date));
      expect(next(date: date).hashCode, next(date: date).hashCode);
      expect(next(date: date), isNot(next()));
      expect(next(), isNot(next(number: 110)));
    });

    test('stored names stay stable', () {
      // Les noms d'enum sont écrits tels quels dans Firestore.
      expect(ReleaseStatus.values.map((v) => v.name), [
        'released',
        'announced',
        'unknown',
      ]);
      expect(ReleaseSource.values.map((v) => v.name), [
        'bnf',
        'googleBooks',
        'user',
      ]);
    });
  });
}
