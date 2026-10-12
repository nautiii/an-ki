import 'package:an_ki/features/birthday/widgets/birth_date_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = BirthDateInputFormatter();

  /// Ce que devient le texte [raw] tapé, le curseur en [caret] (au bout par
  /// défaut).
  TextEditingValue typed(String raw, {int? caret}) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: raw,
          selection: TextSelection.collapsed(offset: caret ?? raw.length),
        ),
      );

  test('masks while typing, the caret staying at the end', () {
    final value = typed('120');

    expect(value.text, '12/0');
    expect(value.selection, const TextSelection.collapsed(offset: 4));
  });

  test('keeps the caret behind the same digits after an edit inside', () {
    // La barre de « 12/03 » effacée revient ; le curseur reste après le 2.
    expect(typed('1203', caret: 2).selection.baseOffset, 2);
    // Un chiffre tapé en tête : le curseur suit ce chiffre.
    final value = typed('312/03', caret: 1);
    expect(value.text, '31/2/03');
    expect(value.selection.baseOffset, 1);
  });

  test('puts the caret first when no digit precedes it', () {
    final value = typed('/12', caret: 1);

    expect(value.text, '12');
    expect(value.selection.baseOffset, 0);
  });

  test('puts the caret at the end without a valid selection', () {
    final value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '1203'),
    );

    expect(value.text, '12/03');
    expect(value.selection.baseOffset, 5);
  });
}
