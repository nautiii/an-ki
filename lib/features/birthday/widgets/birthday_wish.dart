import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/domain/wish_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions du héros le jour J : « Souhaiter » par la feuille de partage, ou
/// « Déjà souhaité » quand c'est fait autrement ; puis la pastille menthe
/// « ✓ Souhaité » à leur place, à la même hauteur : la carte ne saute pas.
class WishActions extends ConsumerWidget {
  const WishActions({
    super.key,
    required this.birthday,
    required this.wished,
    required this.onColor,
  });

  final Birthday birthday;

  /// L'anniversaire du jour est déjà souhaité (`BirthdayWishes.isWished`).
  final bool wished;

  /// Couleur du texte sur le dégradé de fête.
  final Color onColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une seule feuille de partage à la fois.
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );

    if (wished) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: WishedPill(),
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: sharing
                ? null
                : () => wishBirthday(
                    context,
                    birthday,
                    origin: shareOriginOf(buttonContext),
                  ),
            style: FilledButton.styleFrom(
              // 48 dp : une cible confortable, sans le gabarit 56 dp des
              // boutons de bas de feuille.
              minimumSize: const Size(64, kMinInteractiveDimension),
              backgroundColor: onColor,
              foregroundColor: context.ankiColors.onCelebrationAction,
            ),
            icon: const Icon(Icons.send_rounded),
            label: Text(context.l10n.wish),
          ),
        ),
        TextButton(
          onPressed: () => markWishedWithUndo(context, birthday),
          style: TextButton.styleFrom(foregroundColor: onColor),
          child: Text(context.l10n.alreadyWished),
        ),
      ],
    );
  }
}

/// « ✓ Souhaité » en menthe (accent de succès). Dans le héros, haute comme
/// une cible tactile : elle prend la place des boutons sans faire sauter la
/// carte. [dense] dans une ligne (agenda, recherche, feuille du jour), à la
/// taille du compte à rebours « J-12 ».
class WishedPill extends StatelessWidget {
  const WishedPill({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final success = context.ankiColors.success;
    final pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: success.container,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: dense
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              )
            : const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: dense ? 16 : 18,
              color: success.onContainer,
            ),
            SizedBox(width: dense ? AppSpacing.xxs : AppSpacing.xs),
            Flexible(
              child: Text(
                context.l10n.wished,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: success.onContainer),
              ),
            ),
          ],
        ),
      ),
    );

    if (dense) return pill;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: pill,
    );
  }
}

/// Souhaite [birthday] par la feuille de partage du système, avec un message
/// prêt (modifiable dans l'app choisie) ; une app choisie le marque souhaité,
/// avec « Annuler ». [origin] situe la feuille sur iPad ; [belated] prend le
/// message du lendemain, « avec un jour de retard ».
Future<void> wishBirthday(
  BuildContext context,
  Birthday birthday, {
  Rect? origin,
  bool belated = false,
}) async {
  // Tout est lu avant d'ouvrir la feuille : le contexte peut disparaître
  // pendant qu'elle est ouverte.
  final container = ProviderScope.containerOf(context, listen: false);
  final announcer = _WishAnnouncer.of(context, container);
  final year = birthday.wishYear(container.read(todayProvider));
  // Garde le contrôleur en vie tant que la feuille est ouverte.
  final keepAlive = container.listen(birthdayWisherProvider, (_, _) {});
  try {
    final wished = await container
        .read(birthdayWisherProvider.notifier)
        .wish(
          birthdayId: birthday.id,
          year: year,
          message: belated
              ? announcer.l10n.wishMessageBelated(birthday.name)
              : announcer.l10n.wishMessage(birthday.name),
          origin: origin,
        );
    if (wished) announcer.wished(birthday, year);
  } on WishFailure {
    announcer.failed();
  } finally {
    keepAlive.close();
  }
}

/// Marque [birthday] souhaité hors d'AnKi (de vive voix, par téléphone),
/// avec « Annuler ».
void markWishedWithUndo(BuildContext context, Birthday birthday) {
  final container = ProviderScope.containerOf(context, listen: false);
  final year = birthday.wishYear(container.read(todayProvider));
  unawaited(
    container
        .read(birthdayEditorProvider.notifier)
        .markWished(birthday.id, year),
  );
  _WishAnnouncer.of(context, container).wished(birthday, year);
}

/// Annonce l'issue d'un vœu, avec ce qu'il faut lire du contexte avant
/// qu'il ne disparaisse.
class _WishAnnouncer {
  _WishAnnouncer.of(BuildContext context, this.container)
    : l10n = context.l10n,
      messenger = ScaffoldMessenger.of(context),
      accessible = MediaQuery.accessibleNavigationOf(context);

  final ProviderContainer container;
  final AppLocalizations l10n;
  final ScaffoldMessengerState messenger;

  /// TalkBack actif : deux fois plus de temps pour atteindre « Annuler ».
  final bool accessible;

  /// Confirme le vœu (vibration légère, snackbar) et propose de l'annuler :
  /// l'année retirée est celle marquée, même si minuit passe entre-temps.
  void wished(Birthday birthday, int year) {
    unawaited(HapticFeedback.lightImpact());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.birthdayWished(birthday.fullName)),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          duration: accessible ? undoDelay * 2 : undoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(
              container
                  .read(birthdayEditorProvider.notifier)
                  .unmarkWished(birthday.id, year),
            ),
          ),
        ),
      );
  }

  /// La feuille de partage ne s'est pas ouverte.
  void failed() => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.errorSharing)));
}

/// Rectangle du bouton touché, où pointe la feuille de partage sur iPad
/// (`wishBirthday`).
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
