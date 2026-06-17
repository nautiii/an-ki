import 'package:an_ki/core/extensions/common_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringExtensions.capitalize', () {
    test('upper-cases the first letter and lower-cases the rest', () {
      expect('hello'.capitalize(), 'Hello');
      expect('WORLD'.capitalize(), 'World');
      expect('mIxEd'.capitalize(), 'Mixed');
    });

    test('handles a single character', () {
      expect('a'.capitalize(), 'A');
    });
  });
}
