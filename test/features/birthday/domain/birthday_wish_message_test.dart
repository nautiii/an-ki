import 'package:an_ki/features/birthday/domain/birthday_wish_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = 'Bon anniversaire Léa ! 🎂';

  group('customWishMessage', () {
    test('keeps an own message, without spaces around', () {
      expect(
        customWishMessage('  Coucou Léa\n', defaultMessage: fallback),
        'Coucou Léa',
      );
    });

    test('goes back to the default when blank', () {
      expect(customWishMessage('', defaultMessage: fallback), isNull);
      expect(customWishMessage(' \n ', defaultMessage: fallback), isNull);
    });

    test('goes back to the default when it is the default text', () {
      expect(
        customWishMessage(' $fallback ', defaultMessage: fallback),
        isNull,
      );
    });

    test('goes back to the default when only its spaces differ', () {
      expect(
        customWishMessage(
          'Bon  anniversaire Léa ! 🎂',
          defaultMessage: 'Bon anniversaire Léa\u00a0! 🎂',
        ),
        isNull,
      );
    });

    test('keeps a long message whole, emojis included', () {
      final long = '🎂' * wishMessageMaxLength;

      expect(customWishMessage(long, defaultMessage: fallback), long);
    });
  });
}
