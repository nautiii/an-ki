import 'dart:math' as math;

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Date d'anniversaire tapée au clavier : les barres s'insèrent pendant la
/// frappe, et dessous s'affiche un aperçu en clair (« Le 12 mars 1990 · aura
/// 37 ans ») ou une erreur précise.
///
/// Une saisie inachevée n'est signalée en erreur qu'une fois le champ quitté :
/// pendant la frappe, l'aide dit ce qui manque.
class BirthDateField extends StatelessWidget {
  const BirthDateField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.input,
    required this.today,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Focus du champ ; le parent reconstruit le champ quand il change.
  final FocusNode focusNode;

  /// Lecture du texte du champ ([parseBirthDate]), faite par le parent qui en
  /// a aussi besoin pour autoriser l'enregistrement.
  final BirthDateInput input;
  final DateTime today;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typing = focusNode.hasFocus;
    final (String? helper, String? error) = switch (input) {
      BirthDateEmpty() => (l10n.birthYearOptional, null),
      BirthDateIncomplete() when typing => (l10n.birthYearOptional, null),
      BirthDateIncomplete() => (null, l10n.birthDateIncomplete),
      BirthDateInvalid(error: BirthDateError.incompleteYear) when typing => (
        l10n.birthYearDigits,
        null,
      ),
      BirthDateInvalid(error: BirthDateError.incompleteYear) => (
        null,
        l10n.birthYearDigits,
      ),
      BirthDateInvalid(error: BirthDateError.noSuchDate) => (
        null,
        l10n.birthDateInvalid,
      ),
      BirthDateInvalid(error: BirthDateError.future) => (
        null,
        l10n.birthDateFuture,
      ),
      BirthDateComplete(:final date) => (_preview(context, date), null),
    };

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.done,
      inputFormatters: const [BirthDateInputFormatter()],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: l10n.birthdayDate,
        hintText: l10n.birthdayDateHint,
        prefixIcon: const Icon(Icons.cake_outlined),
        helperText: helper,
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 2,
      ),
    );
  }

  /// « Le 12 mars », ou « Le 12 mars 1990 · aura 37 ans » avec l'année.
  String _preview(BuildContext context, BirthDate date) {
    final words = date.formatted(context);
    return switch (date.turningAge(today)) {
      final age? => context.l10n.birthDatePreviewAge(words, age),
      null => context.l10n.birthDatePreview(words),
    };
  }
}

/// Met la saisie en forme pendant la frappe ([maskBirthDateInput]), le
/// curseur restant derrière les mêmes chiffres.
class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final text = maskBirthDateInput(raw);
    final caret = newValue.selection.isValid
        ? math.min(newValue.selection.extentOffset, raw.length)
        : raw.length;
    // Frappe en fin de champ, le cas courant : le curseur reste au bout.
    final offset = caret == raw.length
        ? text.length
        : _offsetAfterDigits(
            text,
            _digit.allMatches(raw.substring(0, caret)).length,
          );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

final _digit = RegExp(r'[0-9]');

/// Position juste après le [count]-ième chiffre de [text], 0 pour aucun.
int _offsetAfterDigits(String text, int count) {
  if (count == 0) return 0;
  var seen = 0;
  for (var i = 0; i < text.length; i++) {
    if (_digit.hasMatch(text[i]) && ++seen == count) return i + 1;
  }
  return text.length;
}
