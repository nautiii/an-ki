import 'dart:math' as math;

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les anniversaires d'hier encore à souhaiter, sous le héros : « Hier », la
/// personne, « Souhaiter » ou « Déjà souhaité ». Le lendemain seulement, sur
/// la surface calme des cartes : un oubli se rattrape sans reproche.
///
/// Rien quand il n'y en a pas ; sinon il porte l'écart qui le sépare du héros.
class BelatedWishes extends ConsumerWidget {
  const BelatedWishes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final belated = ref.watch(belatedBirthdaysProvider);
    if (belated.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, birthday) in belated.indexed) ...[
          SizedBox(height: index == 0 ? AppSpacing.sm : AppSpacing.xs),
          _BelatedCard(birthday: birthday),
        ],
      ],
    );
  }
}

class _BelatedCard extends ConsumerWidget {
  const _BelatedCard({required this.birthday});

  final Birthday birthday;

  static const double _avatarRadius = 20;

  /// Marges du bouton « Souhaiter », fixées ici plutôt que par le thème :
  /// [_actionsWidth] mesure le bouton avec les mêmes.
  static const _wishPadding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.md,
    0,
    AppSpacing.lg,
    0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Une seule feuille de partage à la fois, comme sur le héros.
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );
    final picture = birthday.picture;

    // Toucher la personne ouvre sa fiche, comme sur le héros ; les deux
    // actions restent des cibles à part pour les lecteurs d'écran.
    final identity = MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () =>
              BirthdayFormSheet.show(context, birthdayToEdit: birthday),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              children: [
                AnKiAvatar(
                  name: birthday.fullName,
                  image: picture != null ? MemoryImage(picture) : null,
                  radius: _avatarRadius,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.yesterday,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        birthday.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final wish = Builder(
      builder: (buttonContext) => FilledButton.tonalIcon(
        onPressed: sharing
            ? null
            : () => wishBirthday(
                context,
                birthday,
                origin: shareOriginOf(buttonContext),
                belated: true,
              ),
        style: FilledButton.styleFrom(
          padding: _wishPadding,
          minimumSize: const Size(64, kMinInteractiveDimension),
        ),
        icon: const Icon(Icons.send_rounded),
        label: Text(context.l10n.wish),
      ),
    );
    final alreadyWished = IconButton(
      onPressed: () => markWishedWithUndo(context, birthday),
      tooltip: context.l10n.alreadyWished,
      icon: const Icon(Icons.check_rounded),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Grand texte, ou trop peu de place à côté des actions pour le nom
            // sur deux lignes (écran étroit, nom long) : elles passent
            // dessous et le nom garde la largeur.
            final nameWidth =
                constraints.maxWidth -
                2 * AppSpacing.xs -
                2 * _avatarRadius -
                AppSpacing.sm -
                _actionsWidth(context);
            final largeText =
                MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
            if (largeText || !_fitsOnTwoLines(context, nameWidth)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(child: wish),
                      alreadyWished,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.xs),
                wish,
                alreadyWished,
              ],
            );
          },
        ),
      ),
    );
  }

  /// Largeur des actions sur une ligne : écart, bouton « Souhaiter » (ses
  /// marges [_wishPadding], icône, écart et libellé, 64 dp au moins), puis
  /// l'icône « Déjà souhaité ».
  static double _actionsWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.wish,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final button = math.max(
      64.0,
      _wishPadding.horizontal + 18 + AppSpacing.xs + painter.width,
    );
    painter.dispose();
    return AppSpacing.xs + button + kMinInteractiveDimension;
  }

  /// Le nom tient sur deux lignes de [width] au plus.
  bool _fitsOnTwoLines(BuildContext context, double width) {
    if (width <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(
        text: birthday.fullName,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}
