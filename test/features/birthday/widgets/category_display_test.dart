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
  group('iconData', () {
    // Les icônes doivent être des constantes `Icons.*` : un `IconData` bâti à
    // l'exécution casse l'élagage des icônes de la build release.
    test('is the constant Material icon of a stored code point', () {
      const stored = [
        Icons.category,
        Icons.label_rounded,
        Icons.family_restroom_rounded,
        Icons.pets_rounded,
        Icons.sports_esports_rounded,
      ];
      for (final icon in stored) {
        expect(
          identical(_category('x', icon: icon.codePoint).iconData, icon),
          isTrue,
          reason: '0x${icon.codePoint.toRadixString(16)}',
        );
      }
    });

    test('keeps the icons of the shared and older groups', () {
      // Codes relevés dans Firestore (2026-11-22) : groupes partagés créés à
      // la main dans la console et anciens groupes recopiés.
      const stored = {
        0xf0881: Icons.diversity_1_rounded, // Amis
        0xf02c6: Icons.work_outline_rounded, // Travail
        0xf624: Icons.category_rounded, // Autres
        0xf7c6: Icons.group_rounded, // Famille
        0xf01c8: Icons.sports_tennis_rounded, // Sport
        0xf0306: Icons.diamond_rounded, // OG's
        0xf86b: Icons.local_fire_department_rounded, // BFF
        0xf5b4: Icons.bed_rounded, // Couple
        0xf016a: Icons.share_rounded,
        0xf012e: Icons.school_rounded,
        0xf01bc: Icons.sports_esports_rounded,
        0xf0077: Icons.pets_rounded,
      };
      for (final MapEntry(key: code, value: icon) in stored.entries) {
        expect(
          identical(_category('x', icon: code).iconData, icon),
          isTrue,
          reason: '0x${code.toRadixString(16)}',
        );
      }
    });

    test('falls back to the default group icon for an unknown code', () {
      expect(_category('x', icon: 0x10ffff).iconData, Icons.category);
    });
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

    const labels = {
      'Family': 'Famille',
      'friend': 'Amis',
      'colleague': 'Travail',
      'sport': 'Sport',
      'school': 'École',
      'ogs': "OG's",
      'gaming': 'Gaming',
      'goat': 'GOAT',
      'doggo': 'Doggo',
      'internet': 'Internet',
      'bff': 'BFF',
      'celebrity': 'Célébrité',
      'favorite': 'Favori',
      'couple': 'Couple',
      'other': 'Autres',
      'MyCustom': 'MyCustom',
    };
    for (final MapEntry(key: name, value: label) in labels.entries) {
      expect(_category(name).localizedName(context), label, reason: name);
    }
  });
}
