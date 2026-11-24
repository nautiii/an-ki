import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_check.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/release_date_sheet.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';

enum _SpineKind { owned, missing, coming }

/// Le rayon d'une série : un dos par tome, de 1 au dernier possédé, plus le
/// prochain s'il est paru ou annoncé. Possédé : un dos plein (un toucher
/// ouvre le tome) ; manquant : un emplacement bordé avec « + » (un toucher
/// le marque acheté) ; annoncé : un dos nuage (un toucher saisit la date).
/// Il s'ouvre sur les derniers tomes ; [SpineShelfState.show] fait défiler
/// jusqu'à un numéro. Chaque dos dit à TalkBack son numéro et son état, la
/// couleur n'est jamais le seul indice.
class SpineShelf extends StatefulWidget {
  const SpineShelf({
    super.key,
    required this.entry,
    required this.today,
    required this.onAdd,
  });

  final ShelfEntry entry;
  final DateTime today;

  /// Un emplacement manquant touché : le tome [int] est marqué acheté.
  final ValueChanged<int> onAdd;

  /// Largeur d'une zone tactile ; le dos visible fait 8 dp de moins.
  static const double slot = 48;

  /// Hauteur des dos.
  static const double height = 112;

  @override
  State<SpineShelf> createState() => SpineShelfState();
}

class SpineShelfState extends State<SpineShelf> {
  final _controller = ScrollController();

  /// Le dos visible (40) est centré dans sa zone (48) : la marge du premier
  /// dos s'aligne sur la gouttière.
  static const double _inset = AppSpacing.gutter - AppSpacing.xxs;

  List<int> get _numbers {
    final entry = widget.entry;
    final last = entry.last ?? 0;
    final upcoming = upcomingVolumeNumber(entry);
    final status = nextVolumeStatus(entry, widget.today);
    final shown =
        status == NextVolumeStatus.announced ||
        status == NextVolumeStatus.released;
    return [
      for (var n = 1; n <= last; n++) n,
      if (shown && upcoming != null && upcoming > last) upcoming,
    ];
  }

  @override
  void initState() {
    super.initState();
    // S'ouvre sur les derniers tomes, une fois la liste mesurée.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  /// Fait défiler le rayon pour centrer le tome [number] ; rien pour un
  /// numéro absent du rayon.
  void show(int number) {
    final controller = _controller;
    if (!controller.hasClients) return;
    final index = _numbers.indexOf(number);
    if (index < 0) return;
    final position = controller.position;
    final target =
        (_inset +
                index * SpineShelf.slot -
                (position.viewportDimension - SpineShelf.slot) / 2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = context.motion(AppMotion.page);
    if (duration == Duration.zero) {
      controller.jumpTo(target);
    } else {
      unawaited(
        controller.animateTo(
          target,
          duration: duration,
          curve: AppMotion.standard,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final numbers = _numbers;
    final last = entry.last ?? 0;
    final byNumber = <int, List<Volume>>{};
    for (final volume in entry.volumes) {
      byNumber.putIfAbsent(volume.number!, () => []).add(volume);
    }
    final announced =
        nextVolumeStatus(entry, widget.today) == NextVolumeStatus.announced;
    _SpineKind kindOf(int n) => byNumber.containsKey(n)
        ? _SpineKind.owned
        : n > last && announced
        ? _SpineKind.coming
        : _SpineKind.missing;
    final media = MediaQuery.of(context);

    // Les numéros des dos plafonnent à 130 % : chaque libellé dit tout.
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: Column(
        children: [
          SizedBox(
            height: SpineShelf.height,
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _inset),
              itemExtent: SpineShelf.slot,
              itemCount: numbers.length,
              itemBuilder: (context, i) {
                final number = numbers[i];
                final volumes = byNumber[number] ?? const <Volume>[];
                final kind = kindOf(number);
                return _Spine(
                  number: number,
                  kind: kind,
                  editions: volumes.length,
                  comingLabel: kind == _SpineKind.coming
                      ? ShelfWords(
                          context.l10n,
                          Localizations.localeOf(context).languageCode,
                        ).nextCard(entry, widget.today)
                      : null,
                  onTap: switch (kind) {
                    _SpineKind.owned => () => unawaited(
                      _open(context, number, volumes),
                    ),
                    _SpineKind.missing => () => widget.onAdd(number),
                    _SpineKind.coming => () => unawaited(
                      ReleaseDateSheet.show(
                        context,
                        seriesId: entry.series.id,
                        number: number,
                        current: enteredDateOf(entry),
                      ),
                    ),
                  },
                );
              },
            ),
          ),
          // La planche de l'étagère.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadii.xs)),
                ),
              ),
              child: const SizedBox(
                height: AppSpacing.xs,
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre le tome ; possédé en plusieurs éditions, laisse d'abord choisir.
  static Future<void> _open(
    BuildContext context,
    int number,
    List<Volume> volumes,
  ) async {
    if (volumes.length == 1) {
      return VolumeSheet.show(context, volumes.single.id);
    }
    final picked = await showModalBottomSheet<Volume>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditionPicker(number: number, volumes: volumes),
    );
    if (picked != null && context.mounted) {
      await VolumeSheet.show(context, picked.id);
    }
  }
}

/// Un dos : une zone tactile de 48 dp, un dos visible de 40.
class _Spine extends StatelessWidget {
  const _Spine({
    required this.number,
    required this.kind,
    required this.editions,
    required this.comingLabel,
    required this.onTap,
  });

  final int number;
  final _SpineKind kind;

  /// Éditions possédées de ce numéro.
  final int editions;

  /// Ce que TalkBack lit d'un tome annoncé.
  final String? comingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.ankiColors;
    final numberStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Text numberText(Color color) => Text(
      '$number',
      maxLines: 1,
      softWrap: false,
      style: numberStyle?.copyWith(color: color),
    );
    ShapeBorder shape({Color? side}) => RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.xs)),
      side: side == null ? BorderSide.none : BorderSide(color: side),
    );

    final (Color? fill, ShapeBorder border, Widget face) = switch (kind) {
      _SpineKind.owned => (
        // Un dos sur deux un ton plus profond : des livres, pas un aplat.
        number.isEven ? colors.spine : colors.spineAlt,
        shape(side: colors.spineEdge),
        Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            // Le filet du haut des dos de manga.
            SizedBox(
              height: AppSpacing.xxs,
              width: double.infinity,
              child: ColoredBox(color: colors.onSpine.withValues(alpha: 0.25)),
            ),
            const Spacer(),
            if (editions > 1)
              Badge(label: Text('$editions'), child: numberText(colors.onSpine))
            else
              numberText(colors.onSpine),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
      _SpineKind.missing => (
        null,
        shape(side: colorScheme.outline),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: colorScheme.outline),
            numberText(colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      _SpineKind.coming => (
        colorScheme.tertiaryContainer,
        shape(side: colorScheme.tertiary),
        Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Icon(
              Icons.event_rounded,
              size: AppSpacing.md,
              color: colorScheme.onTertiaryContainer,
            ),
            const Spacer(),
            numberText(colorScheme.onTertiaryContainer),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    };

    return Semantics(
      button: true,
      label: switch (kind) {
        _SpineKind.owned when editions > 1 => l10n.seriesVolumeOwnedEditions(
          number,
          editions,
        ),
        _SpineKind.owned => l10n.seriesVolumeOwned(number),
        _SpineKind.missing => l10n.seriesVolumeMissing(number),
        _SpineKind.coming => comingLabel,
      },
      onTapHint: kind == _SpineKind.missing ? l10n.a11ySpineAddHint : null,
      onTap: onTap,
      excludeSemantics: true,
      // L'encre se peint au-dessus du dos (Ink), pas sous lui.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Ink(
              decoration: ShapeDecoration(color: fill, shape: border),
              child: SizedBox.expand(child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les éditions d'un même numéro : titre et ISBN de chacune.
class _EditionPicker extends StatelessWidget {
  const _EditionPicker({required this.number, required this.volumes});

  final int number;
  final List<Volume> volumes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Semantics(
              header: true,
              child: Text(
                l10n.volumeEditionsTitle(number),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final volume in volumes)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              title: Text(words.volumeTitle(volume)),
              subtitle: volume.isbn == null
                  ? null
                  : Text(l10n.volumeIsbn(volume.isbn!)),
              onTap: () => Navigator.pop(context, volume),
            ),
        ],
      ),
    );
  }
}
