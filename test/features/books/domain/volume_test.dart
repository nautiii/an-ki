import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

Volume volume({
  String id = '9782723492607',
  String? seriesId = 'op',
  int? number = 15,
  List<String> authors = const ['Eiichiro Oda'],
  String? imageUrl,
  LookupState lookup = LookupState.found,
}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  isbn: '9782723492607',
  title: 'Droit devant !!',
  authors: authors,
  imageUrl: imageUrl,
  publisher: 'Glénat',
  publishedDate: '2013',
  lookup: lookup,
  addedAt: DateTime(2026, 11, 8),
);

void main() {
  test('compares by value', () {
    expect(volume(), volume());
    expect(volume().hashCode, volume().hashCode);
    expect(volume(), isNot(volume(id: 'other')));
    expect(volume(), isNot(volume(seriesId: null)));
    expect(volume(), isNot(volume(number: 16)));
    expect(volume(), isNot(volume(authors: const ['Someone'])));
    expect(volume(), isNot(volume(imageUrl: 'https://c/1.jpg')));
    expect(volume(), isNot(volume(lookup: LookupState.pending)));
  });

  test('stored lookup names stay stable', () {
    // Les noms d'enum sont écrits tels quels dans Firestore.
    expect(LookupState.values.map((v) => v.name), [
      'pending',
      'found',
      'notFound',
    ]);
  });
}
