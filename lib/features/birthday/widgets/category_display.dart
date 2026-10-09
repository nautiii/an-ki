import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:flutter/material.dart';

/// Rendu d'une [BirthdayCategory] : icône, couleur et libellé traduit.
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

  /// Couleur d'accent des catégories prédéfinies ; gris sinon.
  Color get color {
    final n = name.toLowerCase();
    if (n == 'family') return Colors.blue;
    if (n == 'friend') return Colors.green;
    if (n == 'colleague') return Colors.orange;
    if (n == 'sport') return Colors.red;
    if (n == 'school') return Colors.purple;
    if (n == 'ogs') return Colors.cyan;
    if (n == 'gaming') return Colors.indigo;
    if (n == 'goat') return Colors.amber;
    if (n == 'doggo') return Colors.brown;
    if (n == 'internet') return Colors.teal;
    if (n == 'bff') return Colors.pink;
    if (n == 'celebrity') return Colors.deepPurple;
    if (n == 'favorite') return Colors.yellow;
    if (n == 'couple') return Colors.deepOrange;
    return Colors.grey;
  }
}
