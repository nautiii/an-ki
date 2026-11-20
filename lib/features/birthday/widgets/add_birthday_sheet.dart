import 'dart:async';

import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/providers/quick_add.dart';
import 'package:an_ki/features/birthday/widgets/add_mode_switch.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_sheet.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille d'ajout d'un anniversaire, en deux modes que l'utilisateur
/// choisit sous le titre ([AddModeSwitch]) : le formulaire, par défaut, ou
/// une seule ligne (« Léa 12 mars »). Le mode change sur place, sans fermer
/// la feuille, et garde ce qui est saisi ([AddHandoff]) ; le dernier choisi
/// est retenu pour le prochain ajout ([quickAddPreferredProvider]).
class AddBirthdaySheet extends ConsumerStatefulWidget {
  const AddBirthdaySheet({super.key, this.initialName});

  /// Nom pré-rempli : le texte d'une recherche sans résultat.
  final String? initialName;

  static Future<bool?> show(BuildContext context, {String? name}) {
    return showModalBottomSheet<bool>(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddBirthdaySheet(initialName: name),
    );
  }

  @override
  ConsumerState<AddBirthdaySheet> createState() => _AddBirthdaySheetState();
}

class _AddBirthdaySheetState extends ConsumerState<AddBirthdaySheet> {
  /// Mode choisi dans cette feuille ; null : celui retenu sur le profil,
  /// suivi tant que l'utilisateur n'a pas choisi (le profil peut arriver
  /// après l'ouverture).
  AddMode? _chosen;
  late AddHandoff _handoff;

  /// Mode montré au dernier build : figé dès la première saisie.
  AddMode _shown = AddMode.form;

  /// Un changement de mode a eu lieu : le nouveau champ prend le focus, le
  /// clavier reste ouvert.
  bool _switched = false;

  @override
  void initState() {
    super.initState();
    _handoff = AddHandoff(name: widget.initialName?.trim() ?? '');
  }

  /// Passe à l'autre mode avec ce qui est saisi, et le retient.
  void _switch(AddMode current, AddHandoff handoff) {
    final next = current == AddMode.form ? AddMode.line : AddMode.form;
    setState(() {
      _chosen = next;
      _handoff = handoff;
      _switched = true;
    });
    unawaited(
      ref
          .read(userProfileEditorProvider.notifier)
          .setQuickAddPreferred(quickAdd: next == AddMode.line),
    );
  }

  /// Première saisie : le mode du profil ne change plus sous les doigts
  /// (un profil arrivé après l'ouverture, un autre appareil qui choisit).
  void _freeze() => _chosen ??= _shown;

  @override
  Widget build(BuildContext context) {
    final handoff = _handoff;
    final mode = _shown =
        _chosen ??
        (ref.watch(quickAddPreferredProvider) ? AddMode.line : AddMode.form);
    final Widget child = switch (mode) {
      AddMode.form => BirthdayFormSheet(
        key: const ValueKey(AddMode.form),
        initialName: handoff.name,
        initialDate: handoff.date,
        initialDateText: handoff.dateText,
        initialLineText: handoff.lineText,
        initialCategories: handoff.categories,
        initialPicture: handoff.picture,
        // Aussi quand le profil change le mode avant toute saisie.
        focusOnStart: _switched || _chosen == null,
        onEdited: _freeze,
        onSwitchMode: (handoff) => _switch(AddMode.form, handoff),
      ),
      AddMode.line => QuickAddSheet(
        key: const ValueKey(AddMode.line),
        initialText: handoff.lineText.isNotEmpty
            ? handoff.lineText
            : [
                handoff.name,
                handoff.dateText,
              ].where((part) => part.isNotEmpty).join(' '),
        initialCategories: handoff.categories,
        initialPicture: handoff.picture,
        // Aussi quand le profil change le mode avant toute saisie.
        focusOnStart: _switched || _chosen == null,
        onEdited: _freeze,
        onSwitchMode: (handoff) => _switch(AddMode.line, handoff),
      ),
    };
    final still = MediaQuery.disableAnimationsOf(context);
    // Un fondu et la hauteur qui suit : la feuille reste la même.
    return AnimatedSize(
      duration: still ? Duration.zero : AppMotion.enter,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : AppMotion.enter,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}
