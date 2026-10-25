import 'package:an_ki/features/auth/domain/sign_up_draft.dart';
import 'package:flutter_test/flutter_test.dart';

SignUpDraft draft({
  String name = 'Léa',
  String surname = 'Martin',
  String email = 'lea@exemple.fr',
  String password = 'secret',
}) =>
    SignUpDraft(name: name, surname: surname, email: email, password: password);

void main() {
  group('SignUpDraft.isValid', () {
    test('accepts a complete form', () {
      expect(draft().isValid, isTrue);
    });

    test('needs a first name, a last name and an address', () {
      expect(draft(name: ' ').isValid, isFalse);
      expect(draft(surname: '').isValid, isFalse);
      expect(draft(email: '  ').isValid, isFalse);
    });

    test('needs a password, typed once', () {
      expect(draft(password: '').isValid, isFalse);
    });
  });

  test('drafts compare by their fields', () {
    expect(draft(), draft());
    expect(draft(), isNot(draft(password: 'other')));
    expect(draft().hashCode, draft().hashCode);
  });
}
