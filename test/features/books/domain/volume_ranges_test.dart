import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/domain/volume_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

VolumeRanges parsed(List<int> numbers) => ParsedVolumeRanges(numbers: numbers);
VolumeRanges rejected(VolumeRangesProblem problem) =>
    RejectedVolumeRanges(problem: problem);

void main() {
  group('parseVolumeRanges accepts', () {
    test('a range and a number', () {
      expect(
        parseVolumeRanges('1-12, 15'),
        parsed([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15]),
      );
    });

    test('a single number', () {
      expect(parseVolumeRanges('7'), parsed([7]));
    });

    test('a one-element range', () {
      expect(parseVolumeRanges('4-4'), parsed([4]));
    });

    test('any spacing around separators', () {
      for (final text in ['1-3,5', ' 1 - 3 ,  5 ', '1 -3, 5', '1- 3;5']) {
        expect(parseVolumeRanges(text), parsed([1, 2, 3, 5]), reason: text);
      }
    });

    test('en and em dashes, the minus sign, « à » and two dots', () {
      for (final text in [
        '1–3',
        '1 — 3',
        '1−3',
        '1 à 3',
        '1 À 3',
        '1 a 3',
        '1‐3', // U+2010
        '1--3',
        '1..3',
        '1 .. 3',
      ]) {
        expect(parseVolumeRanges(text), parsed([1, 2, 3]), reason: text);
      }
    });

    test('commas, semicolons, « et », « & » and spaces between items', () {
      for (final text in [
        '1,2,3',
        '1;2;3',
        '1 et 2 et 3',
        '1 & 2 & 3',
        '1 2 3',
      ]) {
        expect(parseVolumeRanges(text), parsed([1, 2, 3]), reason: text);
      }
    });

    test('a mix like « 1 à 12 et 15 »', () {
      expect(
        parseVolumeRanges('1 à 12 et 15'),
        parsed([...List.generate(12, (i) => i + 1), 15]),
      );
    });

    test('unordered and overlapping parts, sorted and without duplicates', () {
      expect(parseVolumeRanges('15, 1-3, 2-4, 3'), parsed([1, 2, 3, 4, 15]));
    });

    test('the largest allowed number', () {
      expect(parseVolumeRanges('$maxVolumeNumber'), parsed([maxVolumeNumber]));
      expect(
        (parseVolumeRanges(
          '1-$maxVolumeNumber',
        ) as ParsedVolumeRanges).numbers.length,
        maxVolumeNumber,
      );
    });

    test('leading zeros', () {
      expect(parseVolumeRanges('01-03'), parsed([1, 2, 3]));
    });
  });

  group('parseVolumeRanges rejects', () {
    test('an empty input', () {
      for (final text in ['', '   ', ',', ' , ; ']) {
        expect(
          parseVolumeRanges(text),
          rejected(VolumeRangesProblem.empty),
          reason: '"$text"',
        );
      }
    });

    test('an inverted range', () {
      expect(parseVolumeRanges('12-1'), rejected(VolumeRangesProblem.inverted));
      expect(
        parseVolumeRanges('1-3, 9 à 5'),
        rejected(VolumeRangesProblem.inverted),
      );
    });

    test('a huge range or number', () {
      for (final text in [
        '1-${maxVolumeNumber + 1}',
        '1-99999',
        '${maxVolumeNumber + 1}',
        '1-999999999',
      ]) {
        expect(
          parseVolumeRanges(text),
          rejected(VolumeRangesProblem.tooLarge),
          reason: text,
        );
      }
    });

    test('zero, decimals, open ranges and text', () {
      for (final text in [
        '0',
        '0-3',
        '1.5',
        '1-',
        '-3',
        '1-2-3',
        'abc',
        '1, x',
        'tome 3',
        '1/2',
        '-1',
      ]) {
        expect(
          parseVolumeRanges(text),
          rejected(VolumeRangesProblem.malformed),
          reason: text,
        );
      }
    });

    test('a number too long for an int does not crash', () {
      expect(
        parseVolumeRanges('99999999999999999999'),
        rejected(VolumeRangesProblem.malformed),
      );
    });
  });

  test('results compare by value', () {
    expect(parsed([1, 2]), parsed([1, 2]));
    expect(parsed([1, 2]).hashCode, parsed([1, 2]).hashCode);
    expect(parsed([1, 2]), isNot(parsed([1, 3])));
    expect(parsed([1, 2]), isNot(parsed([1])));
    expect(
      rejected(VolumeRangesProblem.empty).hashCode,
      rejected(VolumeRangesProblem.empty).hashCode,
    );
  });
}
