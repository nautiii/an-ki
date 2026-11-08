import 'package:an_ki/core/text/text_folding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldForMatching', () {
    test('lowercases and strips accents', () {
      expect(foldForMatching('Éloïse Çà'), 'eloise ca');
    });

    test('treats hyphens as spaces', () {
      expect(foldForMatching('Jean-Pierre'), 'jean pierre');
    });

    test('collapses and trims whitespace', () {
      expect(foldForMatching('  Anne \t  Marie\n'), 'anne marie');
    });

    test('expands ligatures', () {
      expect(foldForMatching('Cœur Æon'), 'coeur aeon');
    });

    test('keeps digits and unknown characters', () {
      expect(foldForMatching('Tome 12 !'), 'tome 12 !');
    });

    test('keeps letters missing from the table, to keep keys stable', () {
      expect(foldForMatching('Søren Łukasz'), 'søren łukasz');
    });

    test('treats a no-break space as a space', () {
      expect(foldForMatching('Anne Marie'), 'anne marie');
    });

    test('is empty for blank input', () {
      expect(foldForMatching(' \t '), '');
      expect(foldForMatching(''), '');
    });

    test('folds every accented letter of the table', () {
      expect(foldForMatching('àâäáãå'), 'aaaaaa');
      expect(foldForMatching('èéêë'), 'eeee');
      expect(foldForMatching('ìíîï'), 'iiii');
      expect(foldForMatching('òóôöõ'), 'ooooo');
      expect(foldForMatching('ùúûü'), 'uuuu');
      expect(foldForMatching('ýÿñ'), 'yyn');
    });
  });
}
