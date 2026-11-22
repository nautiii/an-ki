import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/stable_hash.dart';
import 'package:flutter/material.dart';

/// Rendu d'une [BirthdayCategory] : icône, teinte et libellé traduit.
extension CategoryDisplay on BirthdayCategory {
  /// Icône Material de la catégorie, retrouvée par son point de code parmi
  /// les icônes qu'un groupe peut porter ; [Icons.category] pour un code
  /// inconnu.
  IconData get iconData => _iconsByCodePoint[icon] ?? Icons.category;

  /// Libellé traduit des catégories prédéfinies ; le nom saisi sinon.
  String localizedName(BuildContext context) {
    final n = name.toLowerCase();
    if (n == 'family') return context.l10n.family;
    if (n == 'friend') return context.l10n.friend;
    if (n == 'colleague') return context.l10n.colleague;
    if (n == 'sport') return context.l10n.sport;
    if (n == 'school') return context.l10n.school;
    if (n == 'ogs') return context.l10n.ogs;
    if (n == 'gaming') return context.l10n.gaming;
    if (n == 'goat') return context.l10n.goat;
    if (n == 'doggo') return context.l10n.doggo;
    if (n == 'internet') return context.l10n.internet;
    if (n == 'bff') return context.l10n.bff;
    if (n == 'celebrity') return context.l10n.celebrity;
    if (n == 'favorite') return context.l10n.favorite;
    if (n == 'couple') return context.l10n.couple;
    if (n == 'other') return context.l10n.other;
    return name;
  }

  /// Teinte de la catégorie : celle choisie à la création, sinon celle d'une
  /// catégorie prédéfinie (gris pour « Autres »), sinon une teinte tirée de
  /// son id, stable : les anciens groupes ne se confondent plus.
  int get toneIndex =>
      tone ??
      switch (name.toLowerCase()) {
        'family' => 0,
        'friend' => 1,
        'colleague' => 2,
        'sport' => 3,
        'school' => 4,
        'ogs' => 5,
        'gaming' => 6,
        'goat' => 7,
        'doggo' => 8,
        'internet' => 9,
        'bff' => 10,
        'celebrity' => 11,
        'favorite' => 12,
        'couple' => 13,
        'other' => LabelTones.neutral,
        _ => LabelTones.pickable[stableHash(id) % LabelTones.pickable.length],
      };

  /// Paire tonale (pastille, puce) de la catégorie pour le thème courant.
  TonalColors tones(BuildContext context) =>
      LabelTones.of(toneIndex, Theme.of(context).brightness);
}

/// Icônes qu'un groupe peut porter : celle d'un groupe sans icône, celle des
/// groupes créés dans l'app, celles que proposait l'ancien choix d'icône, et
/// celles des groupes partagés et anciens saisis à la main dans la console
/// (codes relevés dans Firestore le 2026-11-22).
/// Des constantes `Icons.*` : un `IconData` construit à l'exécution empêche
/// l'élagage de la police d'icônes et fait échouer la build release.
const _groupIcons = [
  Icons.category,
  Icons.label_rounded,
  Icons.category_rounded,
  Icons.group_rounded,
  Icons.family_restroom_rounded,
  Icons.work_rounded,
  Icons.favorite_rounded,
  Icons.contact_support_rounded,
  Icons.star_rounded,
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.celebration_rounded,
  Icons.share_rounded,
  Icons.pets_rounded,
  Icons.sports_martial_arts_rounded,
  Icons.restaurant_rounded,
  Icons.local_library_rounded,
  Icons.sports_esports_rounded,
  Icons.diversity_1_rounded,
  Icons.work_outline_rounded,
  Icons.sports_tennis_rounded,
  Icons.diamond_rounded,
  Icons.local_fire_department_rounded,
  Icons.bed_rounded,
];

final _iconsByCodePoint = {
  for (final icon in _groupIcons) icon.codePoint: icon,
};
