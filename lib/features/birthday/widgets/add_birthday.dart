import 'package:an_ki/features/birthday/providers/quick_add.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre l'ajout d'un anniversaire : le formulaire tant que l'utilisateur
/// n'a jamais ajouté personne avec lui, l'ajout en une ligne ensuite
/// ([quickAddLearnedProvider]). [name] pré-remplit le nom (une recherche
/// sans résultat).
///
/// [ref] est lu tout de suite : un écran qui se ferme peut encore le passer.
Future<bool?> showAddBirthday(
  BuildContext context,
  WidgetRef ref, {
  String? name,
}) => ref.read(quickAddLearnedProvider)
    ? QuickAddSheet.show(context, initialText: name)
    : BirthdayFormSheet.show(context, initialName: name);
