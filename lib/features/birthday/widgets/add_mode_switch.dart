import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Les deux façons d'ajouter quelqu'un : le formulaire (nom, puis date), ou
/// une seule ligne (« Léa 12 mars »).
enum AddMode { form, line }

/// Ce qui est déjà saisi, porté d'un mode à l'autre : rien ne se perd en
/// changeant de mode.
class const AddHandoff({
  /// Prénom et nom, tels que tapés ou compris.
  final String name = '',

  /// La date comprise ; null si elle est absente ou incomplète.
  final BirthDate? date,

  /// La date telle que tapée dans le formulaire (« 12/03 ») : la ligne la
  /// reprend même incomplète.
  final String dateText = '',

  /// La ligne telle que tapée, rendue intacte (« Zoé 12 ») si le formulaire
  /// revient à la ligne sans que le nom ni la date aient changé ; vide sinon.
  final String lineText = '',
  final List<String> categories = const [],
  final Uint8List? picture,
}) {
  @override
  bool operator ==(Object other) =>
      other is AddHandoff &&
      other.name == name &&
      other.date == date &&
      other.dateText == dateText &&
      other.lineText == lineText &&
      listEquals(other.categories, categories) &&
      identical(other.picture, picture);

  @override
  int get hashCode => Object.hash(
    name,
    date,
    dateText,
    lineText,
    Object.hashAll(categories),
    picture,
  );
}

/// Choix du mode, sous le titre de la feuille d'ajout : « Formulaire » ou
/// « En une ligne ». Le segment de [mode] est sélectionné ; toucher l'autre
/// appelle [onChanged]. [lineOnly] grise « Formulaire » : une liste collée
/// ne tient pas dans le formulaire, qui n'en garderait qu'une personne.
class AddModeSwitch extends StatelessWidget {
  const AddModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    this.lineOnly = false,
  });

  final AddMode mode;
  final ValueChanged<AddMode> onChanged;
  final bool lineOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<AddMode>(
      segments: [
        ButtonSegment(
          value: AddMode.form,
          enabled: !lineOnly,
          icon: const Icon(Icons.edit_note_rounded),
          label: Text(l10n.addModeForm),
        ),
        ButtonSegment(
          value: AddMode.line,
          icon: const Icon(Icons.short_text_rounded),
          label: Text(l10n.addModeLine),
        ),
      ],
      selected: {mode},
      // L'icône du mode suffit : pas de coche qui pousse le libellé.
      showSelectedIcon: false,
      onSelectionChanged: (selected) {
        if (selected.single != mode) onChanged(selected.single);
      },
    );
  }
}
