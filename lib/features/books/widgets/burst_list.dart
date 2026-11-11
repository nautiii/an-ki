import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Les tomes de la rafale, le plus récent en haut : « ✓ One Piece · tome
/// 108 », « ISBN 978… · infos à compléter », « Introuvable · Classer ». Un
/// toucher ouvre la correction du tome ([onOpen]).
class BurstList extends StatelessWidget {
  const BurstList({super.key, required this.rows, required this.onOpen});

  final List<BurstRow> rows;
  final ValueChanged<BurstRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xs,
          ),
          // Annoncé par TalkBack à chaque ajout.
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.burstCount(rows.length),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            // Par clé : une ligne qui descend garde son état (sa coche ne
            // se rejoue pas à chaque ajout en tête).
            findChildIndexCallback: (key) {
              final index = rows.indexWhere((r) => ValueKey(r.isbn) == key);
              return index < 0 ? null : index;
            },
            itemBuilder: (context, index) {
              final row = rows[index];
              return _BurstTile(
                key: ValueKey(row.isbn),
                row: row,
                onTap: () => onOpen(row),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Une ligne : une icône d'état, le texte, et la correction d'un toucher.
class _BurstTile extends StatelessWidget {
  const _BurstTile({super.key, required this.row, required this.onTap});

  final BurstRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (row.status) {
      BurstRowStatus.classified => (
        Icons.check_circle_rounded,
        colorScheme.primary,
      ),
      BurstRowStatus.pending => (
        Icons.hourglass_empty_rounded,
        colorScheme.onSurfaceVariant,
      ),
      BurstRowStatus.unclassified => (
        Icons.inbox_rounded,
        colorScheme.secondary,
      ),
      BurstRowStatus.notFound => (
        Icons.help_outline_rounded,
        colorScheme.error,
      ),
    };
    return ListTile(
      onTap: onTap,
      minTileHeight: 48,
      leading: _CheckIn(
        animate: row.status == BurstRowStatus.classified,
        child: Icon(icon, color: color),
      ),
      title: Text(burstRowText(l10n, row)),
      subtitle: row.status == BurstRowStatus.notFound
          ? Text(l10n.volumeIsbn(row.isbn))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Le texte d'une ligne de la rafale.
String burstRowText(AppLocalizations l10n, BurstRow row) =>
    switch (row.status) {
      BurstRowStatus.classified => l10n.burstAdded(
        row.seriesName ?? '',
        row.number ?? 0,
      ),
      BurstRowStatus.pending => l10n.burstPending(row.isbn),
      BurstRowStatus.unclassified => l10n.burstUnclassified(
        row.title.isEmpty ? row.isbn : row.title,
      ),
      BurstRowStatus.notFound => l10n.burstNotFound,
    };

/// Ce qu'on nomme d'un tome possédé : « One Piece 108 », sinon son titre,
/// sinon son ISBN.
String ownedVolumeText(BurstRow row) {
  if (row.seriesName case final name?) {
    return row.number == null ? name : '$name ${row.number}';
  }
  return row.title.isEmpty ? row.isbn : row.title;
}

/// Une coche qui grossit à son arrivée (300 ms), sans animation quand le
/// téléphone les réduit. Une ligne existante ne la rejoue pas (clé par ISBN).
class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: AppMotion.enter,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
