import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

BirthdayCategory _category(String name, {int icon = 0}) =>
    BirthdayCategory(id: '1', name: name, icon: icon);

void main() {
  test('iconData is the MaterialIcons glyph of the stored code point', () {
    final iconData = _category('x', icon: 0xe300).iconData;

    expect(iconData.codePoint, 0xe300);
    expect(iconData.fontFamily, 'MaterialIcons');
  });

  test('color maps known categories and falls back to grey', () {
    expect(_category('family').color, Colors.blue);
    expect(_category('FRIEND').color, Colors.green); // insensible à la casse
    expect(_category('unknown').color, Colors.grey);
    expect(_category('other').color, Colors.grey);
  });

  testWidgets('localizedName translates known keys and echoes custom names', (
    tester,
  ) async {
    final context = await tester.pumpLocalizedContext();

    expect(_category('family').localizedName(context), context.l10n.family);
    expect(_category('MyCustom').localizedName(context), 'MyCustom');
  });
}
