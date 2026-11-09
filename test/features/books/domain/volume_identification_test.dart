import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:flutter_test/flutter_test.dart';

const _isbn = '9782203001152';

void main() {
  test('nobody knows the book: null', () {
    expect(identifyVolume(_isbn), isNull);
  });

  test('the BnF structured series wins, with high confidence', () {
    final identified = identifyVolume(
      _isbn,
      bnf: const BookMetadata(
        title: 'One Piece',
        authors: ['Eiichirō Oda'],
        seriesTitle: 'One Piece',
        seriesNumber: 15,
      ),
      google: const BookMetadata(
        title: 'One Piece - Tome 15',
        authors: [],
        imageUrl: 'https://img/15.jpg',
      ),
    );

    expect(identified?.metadata.imageUrl, 'https://img/15.jpg');
    expect(
      identified?.guess,
      const VolumeGuess(
        seriesName: 'One Piece',
        number: 15,
        confidence: GuessConfidence.high,
      ),
    );
  });

  test('without a BnF series, Google alone may know it better', () {
    // La BnF donne le titre du tome, Google celui de la série : la fusion
    // perd « Tome 11 ».
    final identified = identifyVolume(
      _isbn,
      bnf: const BookMetadata(title: 'Le secret de la Licorne', authors: []),
      google: const BookMetadata(
        title: 'Les Aventures de Tintin',
        subtitle: 'Tome 11 : Le secret de la Licorne',
        authors: [],
      ),
    );

    expect(identified?.metadata.title, 'Le secret de la Licorne');
    expect(identified?.guess?.seriesName, 'Les Aventures de Tintin');
    expect(identified?.guess?.number, 11);
  });

  test('Google alone is guessed once', () {
    final identified = identifyVolume(
      _isbn,
      google: const BookMetadata(title: 'Naruto T12', authors: []),
    );

    expect(identified?.isbn, _isbn);
    expect(identified?.guess?.seriesName, 'Naruto');
    expect(identified?.guess?.confidence, GuessConfidence.medium);
  });

  test('nothing sure: identified, unclassified', () {
    final identified = identifyVolume(
      _isbn,
      bnf: const BookMetadata(title: 'Fahrenheit 451', authors: []),
      google: const BookMetadata(title: 'Fahrenheit 451', authors: []),
    );

    expect(identified, isNotNull);
    expect(identified?.guess, isNull);
  });
}
