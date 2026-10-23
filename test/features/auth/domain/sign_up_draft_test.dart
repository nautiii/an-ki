import 'package:an_ki/features/auth/domain/sign_up_draft.dart';
import 'package:flutter_test/flutter_test.dart';

SignUpDraft draft({
  String name = 'Léa',
  String surname = 'Martin',
  String email = 'lea@exemple.fr',
  String password = 'secret',
  String confirmation = 'secret',
}) => SignUpDraft(
  name: name,
  surname: surname,
  email: email,
  password: password,
  confirmation: confirmation,
);

void main() {
  group('SignUpDraft.isValid', () {
    test('accepts a complete form with the same password twice', () {
      expect(draft().isValid, isTrue);
    });

    test('needs a first name, a last name and an address', () {
      expect(draft(name: ' ').isValid, isFalse);
      expect(draft(surname: '').isValid, isFalse);
      expect(draft(email: '  ').isValid, isFalse);
    });

    test('needs a password, typed twice the same', () {
      expect(draft(password: '', confirmation: '').isValid, isFalse);
      expect(draft(confirmation: 'secreT').isValid, isFalse);
      expect(draft(confirmation: 'secre').isValid, isFalse);
    });
  });

  group('SignUpDraft.confirmationDiffers', () {
    test('says nothing before the confirmation is typed', () {
      expect(
        draft(confirmation: '').confirmationDiffers(typing: true),
        isFalse,
      );
      expect(
        draft(confirmation: '').confirmationDiffers(typing: false),
        isFalse,
      );
    });

    test('while typing, waits as long as it can still match', () {
      expect(
        draft(confirmation: 'sec').confirmationDiffers(typing: true),
        isFalse,
      );
      expect(
        draft(confirmation: 'sex').confirmationDiffers(typing: true),
        isTrue,
      );
      expect(
        draft(confirmation: 'secrets').confirmationDiffers(typing: true),
        isTrue,
      );
    });

    test('once left, any difference shows', () {
      expect(
        draft(confirmation: 'sec').confirmationDiffers(typing: false),
        isTrue,
      );
      // Le brouillon par défaut a deux fois le même mot de passe.
      expect(draft().confirmationDiffers(typing: false), isFalse);
    });

    test('follows a password changed after its confirmation', () {
      expect(
        draft(password: 'secret!').confirmationDiffers(typing: false),
        isTrue,
      );
    });
  });

  test('drafts compare by their fields', () {
    expect(draft(), draft());
    expect(draft(), isNot(draft(confirmation: 'other')));
    expect(draft().hashCode, draft().hashCode);
  });
}
