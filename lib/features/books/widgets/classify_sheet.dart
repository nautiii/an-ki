import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille « Classer ce tome » : sa série (existante ou nouvelle) et son
/// numéro. Écriture optimiste : la feuille se ferme aussitôt, l'étagère
/// annonce un échec.
class ClassifySheet extends ConsumerStatefulWidget {
  const ClassifySheet({super.key, required this.volume});

  final Volume volume;

  static Future<void> show(BuildContext context, Volume volume) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => ClassifySheet(volume: volume),
      );

  @override
  ConsumerState<ClassifySheet> createState() => _ClassifySheetState();
}

/// Valeur du choix « Nouvelle série » parmi les ids de séries.
const _newSeries = '';

class _ClassifySheetState extends ConsumerState<ClassifySheet> {
  /// Série choisie ; celle du tome si elle existe encore (lue au premier
  /// rendu, l'étagère étant déjà chargée).
  late String? _seriesId = _existingSeries(widget.volume.seriesId);
  late final _number = TextEditingController(
    text: widget.volume.number?.toString() ?? '',
  );
  final _name = TextEditingController();

  /// Le nom de la nouvelle série a été touché : son erreur peut s'afficher.
  bool _nameTouched = false;

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _existingSeries(String? seriesId) {
    final entries = ref.read(shelfProvider).value?.entries ?? const [];
    return entries.any((entry) => entry.series.id == seriesId)
        ? seriesId
        : null;
  }

  int? get _parsedNumber {
    final value = int.tryParse(_number.text.trim());
    return value != null && value >= 1 && value <= maxVolumeNumber
        ? value
        : null;
  }

  bool get _nameMissing => _seriesId == _newSeries && _name.text.trim().isEmpty;

  /// Série choisie, numéro valable, nom donné pour une nouvelle série.
  bool get _valid =>
      _seriesId != null && _parsedNumber != null && !_nameMissing;

  void _save() {
    final number = _parsedNumber;
    final seriesId = _seriesId;
    if (!_valid || seriesId == null || number == null) return;
    final editor = ref.read(shelfEditorProvider.notifier);
    final target = seriesId == _newSeries ? _newSeriesId(editor) : seriesId;
    if (target == null) return;
    unawaited(
      editor.classify(widget.volume.id, seriesId: target, number: number),
    );
    unawaited(HapticFeedback.lightImpact());
    Navigator.pop(context);
  }

  /// La série du nom saisi : celle qui porte déjà sa clé (« one piece » pour
  /// « One Piece », un ancien nom compris), sinon une nouvelle. Pas de
  /// doublon parce que la série existante était plus bas dans la liste.
  String? _newSeriesId(ShelfEditor editor) {
    final series = [
      for (final entry
          in ref.read(shelfProvider).value?.entries ?? const <ShelfEntry>[])
        entry.series,
    ];
    final existing = findSeriesByKey(series, seriesKey(_name.text));
    return existing?.id ?? editor.createSeries(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries = searchShelf(
      ref.watch(shelfProvider).value?.entries ?? const [],
      '',
    );
    // Une erreur dès que le champ dit quelque chose de faux, pas avant.
    final numberError = _number.text.isNotEmpty && _parsedNumber == null
        ? l10n.classifyNumberError(maxVolumeNumber)
        : null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.classifyTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: RadioGroup<String>(
                groupValue: _seriesId,
                onChanged: (value) => setState(() => _seriesId = value),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Text(
                        l10n.classifySeries,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final entry in entries)
                      RadioListTile<String>(
                        value: entry.series.id,
                        title: Text(entry.series.name),
                      ),
                    const RadioListTile<String>(
                      value: _newSeries,
                      title: _NewSeriesLabel(),
                    ),
                    if (_seriesId == _newSeries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: TextField(
                          controller: _name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() => _nameTouched = true),
                          decoration: InputDecoration(
                            labelText: l10n.seriesNameLabel,
                            errorText: _nameTouched && _nameMissing
                                ? l10n.seriesNameRequired
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _number,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: l10n.classifyNumberLabel,
                      errorText: numberError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _valid ? _save : null,
                    child: Text(l10n.classifySave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSeriesLabel extends StatelessWidget {
  const _NewSeriesLabel();

  @override
  Widget build(BuildContext context) => Text(context.l10n.classifyNewSeries);
}
