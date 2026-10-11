import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:flutter/material.dart';

/// Rendu d'une [BirthdayCategory] : icône, teinte et libellé traduit.
extension CategoryDisplay on BirthdayCategory {
  /// Icône Material de la catégorie.
  // ignore: non_const_argument_for_const_parameter
  IconData get iconData => IconData(icon, fontFamily: 'MaterialIcons');

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

  /// Teinte des catégories prédéfinies ; neutre pour les catégories créées.
  int get toneIndex => switch (name.toLowerCase()) {
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
    _ => LabelTones.neutral,
  };

  /// Paire tonale (pastille, puce) de la catégorie pour le thème courant.
  TonalColors tones(BuildContext context) =>
      LabelTones.of(toneIndex, Theme.of(context).brightness);
}
