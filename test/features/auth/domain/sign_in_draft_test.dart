import 'package:an_ki/features/auth/domain/sign_in_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignInDraft', () {
    test('is valid with an address and a password', () {
      expect(
        const SignInDraft(email: 'lea@exemple.fr', password: 'secret').isValid,
        isTrue,
      );
    });

    test('needs both fields, spaces alone are no address', () {
      expect(const SignInDraft(email: '', password: 'secret').isValid, isFalse);
      expect(
        const SignInDraft(email: '   ', password: 'secret').isValid,
        isFalse,
      );
      expect(
        const SignInDraft(email: 'lea@exemple.fr', password: '').isValid,
        isFalse,
      );
    });

    test('has an address for the forgotten password link, spaces aside', () {
      expect(
        const SignInDraft(email: ' lea@exemple.fr ', password: '').hasEmail,
        isTrue,
      );
      expect(const SignInDraft(email: '  ', password: 'x').hasEmail, isFalse);
    });

    test('keeps a password made of spaces as typed', () {
      expect(
        const SignInDraft(email: 'lea@exemple.fr', password: '  ').isValid,
        isTrue,
      );
    });

    test('drafts compare by their fields', () {
      const draft = SignInDraft(email: 'a@b.fr', password: 'x');

      expect(draft, const SignInDraft(email: 'a@b.fr', password: 'x'));
      expect(draft, isNot(const SignInDraft(email: 'a@b.fr', password: 'y')));
      expect(
        draft.hashCode,
        const SignInDraft(email: 'a@b.fr', password: 'x').hashCode,
      );
    });
  });
}
