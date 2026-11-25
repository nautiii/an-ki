import 'dart:async';
import 'dart:math' as math;

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:an_ki/features/books/domain/volume_ranges.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/widgets/book_sheet_header.dart';
import 'package:an_ki/features/books/widgets/volume_range_preview.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille « Ajouter une série » : une collection déjà sur l'étagère, sans
/// 120 scans. Un nom (avec les séries existantes en suggestion), « J'ai les
/// tomes 1-12, 15 » (`parseVolumeRanges`), « Série terminée ». Renvoie l'id
/// de la série, ou null si elle est fermée sans rien.
///
/// Écriture optimiste : la feuille se ferme aussitôt, l'étagère annonce un
/// échec.
class AddSeriesSheet extends ConsumerStatefulWidget {
  const AddSeriesSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const AddSeriesSheet(),
      );

  @override
  ConsumerState<AddSeriesSheet> createState() => _AddSeriesSheetState();
}

/// Suggestions de séries montrées sous le nom, au plus.
const _maxSuggestions = 4;

class _AddSeriesSheetState extends ConsumerState<AddSeriesSheet> {
  final _name = TextEditingController();
  final _ranges = TextEditingController();
  bool _complete = false;

  /// Les erreurs s'affichent une fois le champ touché, pas avant.
  bool _nameTouched = false;
  bool _rangesTouched = false;

  @override
  void dispose() {
    _name.dispose();
    _ranges.dispose();
    super.dispose();
  }

  void _save() {
    final ranges = parseVolumeRanges(_ranges.text);
    if (seriesKey(_name.text).isEmpty || ranges is! ParsedVolumeRanges) {
      setState(() => _nameTouched = _rangesTouched = true);
      return;
    }
    final id = ref
        .read(shelfEditorProvider.notifier)
        .addSeriesByHand(_name.text, ranges.numbers, complete: _complete);
    if (id == null) return;
    unawaited(HapticFeedback.lightImpact());
    Navigator.pop(context, id);
  }

  void _pick(String name) {
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() => _nameTouched = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Suit l'étagère : elle peut changer sous la feuille.
    final entries =
        ref.watch(shelfProvider).value?.entries ?? const <ShelfEntry>[];
    final name = _name.text.trim();
    final key = seriesKey(name);
    final joined = key.isEmpty
        ? null
        : findSeriesByKey([for (final e in entries) e.series], key);
    final suggestions = name.isEmpty || joined != null
        ? const <ShelfEntry>[]
        : searchShelf(entries, name).take(_maxSuggestions).toList();
    final ranges = parseVolumeRanges(_ranges.text);
    final rangesError = _rangesTouched && ranges is RejectedVolumeRanges
        ? _rangesMessage(l10n, ranges.problem)
        : null;
    // Un nom fait de ponctuation seule n'a pas de clé : il ne nomme rien.
    final valid = key.isNotEmpty && ranges is ParsedVolumeRanges;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        // Le clavier, sinon la barre système (`useSafeArea` laisse le bas).
        AppSpacing.lg +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.paddingOf(context).bottom,
            ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BookSheetHeader(
            leading: const BookSheetIcon(icon: Icons.library_add_rounded),
            title: l10n.addSeriesTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _nameTouched = true),
            decoration: InputDecoration(
              labelText: l10n.seriesNameLabel,
              errorText: _nameTouched && key.isEmpty
                  ? l10n.seriesNameRequired
                  : null,
              helperText: joined == null
                  ? null
                  : l10n.addSeriesJoins(joined.name),
              helperMaxLines: 3,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final entry in suggestions)
                  ActionChip(
                    label: Text(entry.series.name),
                    onPressed: () => _pick(entry.series.name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ranges,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() => _rangesTouched = true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.addSeriesVolumesLabel,
              hintText: l10n.addSeriesVolumesHint,
              helperText: rangesError == null
                  ? l10n.addSeriesVolumesHelper
                  : null,
              helperMaxLines: 3,
              errorText: rangesError,
              errorMaxLines: 3,
            ),
          ),
          // Ce que la saisie va créer, avant « Ajouter ».
          if (ranges case ParsedVolumeRanges(:final numbers)
              when numbers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            VolumeRangePreview(
              numbers: numbers,
              alreadyOwned: [
                for (final entry in entries)
                  if (entry.series.id == joined?.id) ...entry.owned,
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _complete,
            onChanged: (value) => setState(() => _complete = value),
            title: Text(l10n.addSeriesComplete),
            subtitle: Text(l10n.addSeriesCompleteHint),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: valid ? _save : null, child: Text(l10n.add)),
        ],
      ),
    );
  }
}

/// Le message d'une saisie de tomes refusée.
String _rangesMessage(AppLocalizations l10n, VolumeRangesProblem problem) =>
    switch (problem) {
      VolumeRangesProblem.empty => l10n.rangesEmpty,
      VolumeRangesProblem.malformed => l10n.rangesMalformed,
      VolumeRangesProblem.inverted => l10n.rangesInverted,
      VolumeRangesProblem.tooLarge => l10n.rangesTooLarge(maxVolumeNumber),
    };
