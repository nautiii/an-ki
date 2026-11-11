import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:flutter/material.dart';

/// Feuille « Saisir un ISBN » : le repli quand le code-barres ne se lit pas.
/// Renvoie l'ISBN-13 normalisé, ou null si elle est fermée sans rien.
///
/// Validé par `normalizeIsbn` (ISBN-10 ou 13, tirets et espaces tolérés, clé
/// de contrôle vérifiée) : une faute de frappe s'affiche sous le champ.
class IsbnEntrySheet extends StatefulWidget {
  const IsbnEntrySheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const IsbnEntrySheet(),
      );

  @override
  State<IsbnEntrySheet> createState() => _IsbnEntrySheetState();
}

class _IsbnEntrySheetState extends State<IsbnEntrySheet> {
  final _controller = TextEditingController();

  /// L'erreur s'affiche après une tentative, puis suit la saisie.
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final isbn = normalizeIsbn(_controller.text);
    if (isbn == null) {
      setState(() => _submitted = true);
      return;
    }
    Navigator.pop(context, isbn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = _controller.text.trim();
    final error = _submitted && normalizeIsbn(text) == null
        ? (text.isEmpty ? l10n.isbnEntryEmpty : l10n.isbnEntryInvalid)
        : null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.isbnEntryTitle,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            // Un ISBN-10 peut finir par X : un clavier de texte, en
            // majuscules, sans correction.
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.isbnEntryLabel,
              hintText: l10n.isbnEntryHint,
              helperText: error == null ? l10n.isbnEntryHelper : null,
              helperMaxLines: 3,
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: text.isEmpty ? null : _submit,
              child: Text(l10n.add),
            ),
          ),
        ],
      ),
    );
  }
}
