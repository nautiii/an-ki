import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Feuille « Sortie du tome 109 » : la date vue sur une affiche ou le site de
/// l'éditeur, au jour ou au mois seul, gardée comme « date saisie par vous ».
/// [current] (une date déjà saisie) la préremplit et permet de l'effacer.
///
/// L'écriture passe par `ShelfEditor` sans être attendue : hors ligne, elle
/// part au retour du réseau, et l'étagère annonce un refus.
class ReleaseDateSheet extends ConsumerStatefulWidget {
  const ReleaseDateSheet({
    super.key,
    required this.seriesId,
    required this.number,
    this.current,
  });

  final String seriesId;
  final int number;
  final ReleaseDate? current;

  static Future<void> show(
    BuildContext context, {
    required String seriesId,
    required int number,
    ReleaseDate? current,
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        ReleaseDateSheet(seriesId: seriesId, number: number, current: current),
  );

  @override
  ConsumerState<ReleaseDateSheet> createState() => _ReleaseDateSheetState();
}

class _ReleaseDateSheetState extends ConsumerState<ReleaseDateSheet> {
  /// Jour choisi au calendrier (le premier du mois pour une date au mois).
  DateTime? _picked;
  bool _monthOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.current case final current?) {
      _picked = DateTime(current.year, current.month, current.day ?? 1);
      _monthOnly = current.isMonthOnly;
    }
  }

  ReleaseDate? get _date {
    final picked = _picked;
    if (picked == null) return null;
    return ReleaseDate(
      year: picked.year,
      month: picked.month,
      day: _monthOnly ? null : picked.day,
    );
  }

  Future<void> _pick() async {
    final today = ref.read(todayProvider);
    final initial = _picked ?? today;
    // Un tome paru depuis peu se saisit aussi ; au-delà, le calendrier
    // n'aide plus, sauf pour garder une date saisie plus ancienne.
    final oneYearAgo = DateTime(today.year - 1, today.month, today.day);
    final lastDate = DateTime(today.year + 3, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(oneYearAgo) ? initial : oneYearAgo,
      lastDate: initial.isAfter(lastDate) ? initial : lastDate,
    );
    if (picked != null && mounted) setState(() => _picked = picked);
  }

  void _save(ReleaseDate? date) {
    // Lancée avant de fermer : l'éditeur la mène même si la feuille part.
    ref
        .read(shelfEditorProvider.notifier)
        .enterReleaseDate(widget.seriesId, widget.number, date)
        .ignore();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final picked = _picked;
    final date = _date;
    final label = picked == null
        ? l10n.releaseSheetPick
        : _monthOnly
        ? DateFormat.yMMMM(locale).format(picked)
        : DateFormat.yMMMMd(locale).format(picked);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.releaseSheetTitle(widget.number),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.releaseSheetHelper,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(label),
          ),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.releaseSheetMonthOnly),
            value: _monthOnly,
            onChanged: (value) => setState(() => _monthOnly = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (widget.current != null)
                TextButton(
                  onPressed: () => _save(null),
                  child: Text(l10n.releaseSheetClear),
                ),
              FilledButton(
                onPressed: date == null || date == widget.current
                    ? null
                    : () => _save(date),
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
