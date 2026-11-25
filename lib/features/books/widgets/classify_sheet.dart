import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/book_sheet_header.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille « Classer ce tome » : chercher sa série, ou la créer du nom tapé,
/// puis son numéro. Elle s'ouvre sur la série et le numéro proposés (ceux
/// donnés, sinon ceux du tome, sinon la suggestion d'« À classer ») : souvent
/// il ne reste qu'à toucher « Ranger ». Écriture optimiste : la feuille se
/// ferme aussitôt, l'étagère annonce un échec.
class ClassifySheet extends ConsumerStatefulWidget {
  const ClassifySheet({
    super.key,
    required this.volume,
    this.seriesId,
    this.number,
  });

  final Volume volume;

  /// Série et numéro proposés (une suggestion d'« À classer ») ; sinon ceux
  /// du tome.
  final String? seriesId;
  final int? number;

  static Future<void> show(
    BuildContext context,
    Volume volume, {
    String? seriesId,
    int? number,
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        ClassifySheet(volume: volume, seriesId: seriesId, number: number),
  );

  @override
  ConsumerState<ClassifySheet> createState() => _ClassifySheetState();
}

/// Valeur du choix « Créer » parmi les ids de séries.
const _newSeries = '';

class _ClassifySheetState extends ConsumerState<ClassifySheet> {
  /// Recherche, et nom de la série à créer.
  final _query = TextEditingController();
  final _number = TextEditingController();

  /// Série choisie : un id, [_newSeries], ou null.
  String? _seriesId;

  /// Le numéro a été tapé : choisir une série ne le change plus.
  bool _numberTouched = false;

  /// La recherche et le bas de la feuille gardent leur état (saisie, focus)
  /// quand le clavier change la forme de la feuille.
  final _searchKey = GlobalKey();
  final _footerKey = GlobalKey();

  /// Nom de la série que la suggestion propose de créer : la ligne « Créer »
  /// le porte tant que rien n'est tapé, sans filtrer la liste.
  String? _suggestedName;

  /// Nom de la série à créer : celui tapé, sinon celui de la suggestion.
  String get _newName =>
      _query.text.trim().isNotEmpty ? _query.text : _suggestedName ?? '';

  @override
  void initState() {
    super.initState();
    final volume = widget.volume;
    String? seriesId = _existing(widget.seriesId ?? volume.seriesId);
    var number = widget.number ?? volume.number;
    // Un tome à classer, sans proposition donnée : celle d'« À classer ».
    if (seriesId == null && widget.seriesId == null) {
      final suggestion = ref.read(placementSuggestionProvider(volume.id));
      if (suggestion != null) {
        number ??= suggestion.number;
        if (suggestion.series case final series?) {
          seriesId = _existing(series.id);
        } else {
          seriesId = _newSeries;
          _suggestedName = suggestion.seriesName;
        }
      }
    }
    _seriesId = seriesId;
    _number.text = number?.toString() ?? '';
    // Un numéro connu (le tome, ou celui donné) ne change pas avec la série.
    _numberTouched = (widget.number ?? volume.number) != null;
  }

  @override
  void dispose() {
    _query.dispose();
    _number.dispose();
    super.dispose();
  }

  List<ShelfEntry> _entries() =>
      ref.read(shelfProvider).value?.entries ?? const [];

  /// [seriesId] s'il est encore sur l'étagère (lue au premier rendu, déjà
  /// chargée par l'écran qui ouvre la feuille).
  String? _existing(String? seriesId) =>
      _entries().any((entry) => entry.series.id == seriesId) ? seriesId : null;

  /// La série du nom tapé, si elle existe déjà (un ancien nom compris).
  ShelfEntry? _named(List<ShelfEntry> entries) {
    final key = seriesKey(_newName);
    if (key.isEmpty) return null;
    final found = findSeriesByKey([for (final e in entries) e.series], key);
    return entries.where((e) => e.series.id == found?.id).firstOrNull;
  }

  int? get _parsedNumber {
    final value = int.tryParse(_number.text.trim());
    return value != null && value >= 1 && value <= maxVolumeNumber
        ? value
        : null;
  }

  /// Une série choisie (créer : un nom qui en est un), un numéro valable.
  bool get _valid =>
      _seriesId != null &&
      _parsedNumber != null &&
      (_seriesId != _newSeries || seriesKey(_newName).isNotEmpty);

  void _select(String? seriesId) {
    setState(() {
      _seriesId = seriesId;
      _fillNumber(seriesId);
    });
  }

  /// Le prochain numéro de la série [seriesId] (`nextNumberOf`), tant qu'aucun
  /// numéro n'est connu ni tapé. Un tome qui a déjà un numéro le garde d'une
  /// série à l'autre (un tome 7 déplacé reste le tome 7) ; seul le numéro
  /// d'une suggestion cède la place.
  void _fillNumber(String? seriesId) {
    final entry = _entries().where((e) => e.series.id == seriesId).firstOrNull;
    if (!_numberTouched && entry != null) {
      _number.text = '${nextNumberOf(entry)}';
    }
  }

  void _onQuery(String _) {
    setState(() {
      // « Créer » sur un nom qui existe déjà : c'est cette série.
      if (_seriesId == _newSeries) {
        final named = _named(_entries());
        if (named != null) {
          _seriesId = named.series.id;
          _fillNumber(named.series.id);
        }
      }
    });
  }

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

  /// La série du nom tapé : celle qui porte déjà sa clé, sinon une nouvelle.
  String? _newSeriesId(ShelfEditor editor) =>
      _named(_entries())?.series.id ?? editor.createSeries(_newName);

  /// Vrai quand le numéro, dans la série choisie (ou celle du nom tapé),
  /// ferait un deuxième exemplaire (`wouldDuplicate`) : permis, mais dit.
  bool _duplicate(List<ShelfEntry> entries) {
    final number = _parsedNumber;
    final entry = _seriesId == _newSeries
        ? _named(entries)
        : entries.where((e) => e.series.id == _seriesId).firstOrNull;
    if (number == null || entry == null) return false;
    return wouldDuplicate(
      entry.volumes,
      widget.volume,
      seriesId: entry.series.id,
      number: number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(shelfProvider).value?.entries ?? const [];
    final query = _query.text.trim();
    final found = searchShelf(entries, query);
    // La série choisie reste en tête, même hors de la recherche.
    final chosen = entries.where((e) => e.series.id == _seriesId).firstOrNull;
    final rows = [
      if (chosen != null && !found.contains(chosen)) chosen,
      ...found,
    ];
    final newName = _newName.trim();
    // Un nom fait de ponctuation seule ne nomme rien : pas de « Créer ».
    final canCreate = seriesKey(newName).isNotEmpty && _named(entries) == null;
    // Une erreur dès que le champ dit quelque chose de faux, pas avant.
    final numberError = _number.text.isNotEmpty && _parsedNumber == null
        ? l10n.classifyNumberError(maxVolumeNumber)
        : null;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = (MediaQuery.sizeOf(context).height - keyboard) * 0.85;

    final search = Padding(
      key: _searchKey,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: _query,
        textCapitalization: TextCapitalization.sentences,
        onChanged: _onQuery,
        decoration: InputDecoration(
          labelText: l10n.classifySearchLabel,
          prefixIcon: const Icon(Icons.search_rounded),
          helperText: entries.isEmpty ? l10n.classifyNoSeries : null,
          helperMaxLines: 3,
        ),
      ),
    );
    final choices = [
      if (canCreate)
        RadioListTile<String>(
          value: _newSeries,
          secondary: const Icon(Icons.library_add_rounded),
          title: Text(l10n.classifyCreate(newName)),
        ),
      for (final entry in rows) _SeriesRow(entry: entry),
    ];
    final footer = Padding(
      key: _footerKey,
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
            onChanged: (_) => setState(() => _numberTouched = true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.classifyNumberLabel,
              errorText: numberError,
              helperText: _duplicate(entries)
                  ? l10n.classifyDuplicateHint
                  : null,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _valid ? _save : null,
            child: Text(l10n.classifySave),
          ),
        ],
      ),
    );

    // Clavier ouvert : sans l'en-tête, et tout défile d'un bloc, la place
    // manque sur un petit téléphone. Tout est construit (pas de liste
    // paresseuse) : les champs, à clé globale, passent d'une forme à l'autre
    // sans perdre leur saisie ni le focus.
    final Widget body = keyboard > 0
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: AppSpacing.xs),
                ...choices,
                footer,
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: BookSheetHeader(
                  leading: SeriesCover(
                    name: widget.volume.title,
                    imageUrl: widget.volume.imageUrl,
                  ),
                  title: l10n.classifyTitle,
                  subtitle: words.volumeTitle(widget.volume),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              search,
              const SizedBox(height: AppSpacing.xs),
              Flexible(child: ListView(shrinkWrap: true, children: choices)),
              footer,
            ],
          );

    return Padding(
      // Le clavier, sinon la barre système (`useSafeArea` laisse le bas).
      padding: EdgeInsets.only(
        bottom: keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: RadioGroup<String>(
          groupValue: _seriesId,
          onChanged: _select,
          child: body,
        ),
      ),
    );
  }
}

/// Une série à choisir : sa couverture en petit, son nom, son dernier tome.
class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.entry});

  final ShelfEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RadioListTile<String>(
      value: entry.series.id,
      secondary: SeriesCover(
        name: entry.series.name,
        imageUrl: entry.coverUrl,
        width: 32,
      ),
      title: Text(entry.series.name),
      subtitle: Text(switch (entry.last) {
        final last? => l10n.classifySeriesLast(last),
        null => l10n.classifySeriesEmpty,
      }),
    );
  }
}
