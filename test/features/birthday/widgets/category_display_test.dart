import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

BirthdayCategory _category(
  String name, {
  int icon = 0,
  String id = '1',
  int? tone,
}) => BirthdayCategory(id: id, name: name, icon: icon, tone: tone);

void main() {
  test('iconData is the MaterialIcons glyph of the stored code point', () {
    final iconData = _category('x', icon: 0xe300).iconData;

    expect(iconData.codePoint, 0xe300);
    expect(iconData.fontFamily, 'MaterialIcons');
  });

  test('toneIndex gives each known category its own tone', () {
    const known = [
      'family',
      'friend',
      'colleague',
      'sport',
      'school',
      'ogs',
      'gaming',
      'goat',
      'doggo',
      'internet',
      'bff',
      'celebrity',
      'favorite',
      'couple',
    ];
    final tones = {for (final name in known) _category(name).toneIndex};

    expect(tones, hasLength(known.length));
    expect(tones, isNot(contains(LabelTones.neutral)));
    expect(_category('FRIEND').toneIndex, _category('friend').toneIndex);
  });

  test('« Autres » keeps the neutral tone', () {
    expect(_category('other').toneIndex, LabelTones.neutral);
  });

  test('toneIndex takes the tone picked at creation first', () {
    expect(_category('Voisins', tone: 9).toneIndex, 9);
    expect(_category('family', tone: 5).toneIndex, 5);
  });

  test('an older group without tone gets a pickable one from its id', () {
    final groups = [
      for (final id in ['a1', 'b2', 'c3', 'd4', 'e5', 'f6'])
        _category('Club', id: id),
    ];

    for (final group in groups) {
      expect(LabelTones.pickable, contains(group.toneIndex));
      // Stable : le même id donne toujours la même teinte.
      expect(_category('Autre nom', id: group.id).toneIndex, group.toneIndex);
    }
    // Des ids différents ne se confondent pas tous.
    expect(
      {for (final group in groups) group.toneIndex}.length,
      greaterThan(1),
    );
  });

  testWidgets('tones follow the theme brightness', (tester) async {
    final context = await tester.pumpLocalizedContext();

    expect(
      _category('family').tones(context),
      LabelTones.of(0, Theme.of(context).brightness),
    );
  });

  testWidgets('localizedName translates known keys and echoes custom names', (
    tester,
  ) async {
    final context = await tester.pumpLocalizedContext();

    expect(_category('family').localizedName(context), context.l10n.family);
    expect(_category('MyCustom').localizedName(context), 'MyCustom');
  });
}
