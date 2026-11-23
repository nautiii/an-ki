import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/domain/wish_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/providers/contact_links.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/wish_bubble.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions du héros le jour J, tant que l'anniversaire n'est pas souhaité :
/// le message dans sa bulle ([WishBubble], qui ouvre les autres), puis
/// « Souhaiter » qui l'envoie par la feuille de partage, ou « Déjà
/// souhaité » quand c'est fait autrement. Une fois le vœu fait, le héros
/// les retire.
///
/// Personne reliée à son contact (P5) : « Message » ouvre sa conversation
/// SMS, texte prêt ; « Appeler » le composeur ; « Autre app » garde la
/// feuille de partage (WhatsApp…).
class WishActions extends ConsumerWidget {
  const WishActions({super.key, required this.birthday, required this.onColor});

  final Birthday birthday;

  /// Couleur du texte sur le dégradé de fête.
  final Color onColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une seule feuille de partage à la fois.
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );
    final link = ref.watch(contactLinkProvider(birthday.id));

    final buttons = Wrap(
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
            icon: Icon(link == null ? Icons.send_rounded : Icons.sms_rounded),
            label: Text(
              link == null ? context.l10n.wish : context.l10n.contactMessage,
            ),
          ),
        ),
        if (link != null) ...[
          IconButton(
            onPressed: sharing ? null : () => callToWish(context, birthday),
            tooltip: context.l10n.contactCall,
            style: IconButton.styleFrom(
              foregroundColor: onColor,
              // Le voile de la bulle : au plus 16 % (audit de palette).
              backgroundColor: onColor.withValues(alpha: 0.16),
            ),
            icon: const Icon(Icons.call_rounded),
          ),
          Builder(
            builder: (buttonContext) => TextButton(
              onPressed: sharing
                  ? null
                  : () => wishBirthday(
                      context,
                      birthday,
                      origin: shareOriginOf(buttonContext),
                      share: true,
                    ),
              style: TextButton.styleFrom(foregroundColor: onColor),
              child: Text(context.l10n.wishOtherApp),
            ),
          ),
        ],
        TextButton(
          onPressed: () => markWishedWithUndo(context, birthday),
          style: TextButton.styleFrom(foregroundColor: onColor),
          child: Text(context.l10n.alreadyWished),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Un voile du texte de fête : au plus 16 %, au-delà le contraste
        // tombe sous 4,5:1 en sombre (audit de palette).
        WishBubble(
          birthday: birthday,
          fill: onColor.withValues(alpha: 0.16),
          onFill: onColor,
        ),
        const SizedBox(height: AppSpacing.sm),
        buttons,
      ],
    );
  }
}

/// « ✓ Souhaité » en menthe (accent de succès), dans une phrase ou une
/// ligne, à la hauteur du texte : la carte du jour J sur l'accueil, l'en-tête
/// de la fiche le jour J et le lendemain.
class WishedPill extends StatelessWidget {
  const WishedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final success = context.ankiColors.success;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: success.container,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 16, color: success.onContainer),
            const SizedBox(width: AppSpacing.xxs),
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
  }
}

/// Souhaite [birthday] avec [message] prêt (modifiable dans l'app) : par
/// défaut le premier vœu suggéré (le sien s'il en a un). Reliée à son
/// contact, la personne reçoit un SMS (sa conversation s'ouvre) ; sinon, ou
/// avec [share], la feuille de partage du système. L'app ouverte ou choisie
/// le marque souhaité, avec « Annuler ». [origin] situe la feuille sur iPad.
Future<void> wishBirthday(
  BuildContext context,
  Birthday birthday, {
  Rect? origin,
  String? message,
  bool share = false,
}) async {
  // Tout est lu avant d'ouvrir la feuille : le contexte peut disparaître
  // pendant qu'elle est ouverte.
  final container = ProviderScope.containerOf(context, listen: false);
  final announcer = _WishAnnouncer.of(context, container);
  final today = container.read(todayProvider);
  final year = birthday.wishYear(today);
  final text =
      message ??
      wishTexts(
        announcer.l10n,
        birthday.name,
        container.read(wishSuggestionsProvider(birthday)),
      ).first;
  // Garde le contrôleur en vie tant que la feuille est ouverte.
  final keepAlive = container.listen(birthdayWisherProvider, (_, _) {});
  // Les liaisons attendues, pas lues telles quelles : ouverte à froid par la
  // notification, l'app ne les a peut-être pas encore lues sur le téléphone.
  final linksAlive = container.listen(contactLinksProvider, (_, _) {});
  try {
    final links = container.read(contactLinksProvider);
    final smsTo = share
        ? null
        : (links.hasValue
                  ? links.requireValue
                  : await container.read(
                      contactLinksProvider.future,
                    ))[birthday.id]
              ?.number;
    final wished = await container
        .read(birthdayWisherProvider.notifier)
        .wish(
          birthdayId: birthday.id,
          year: year,
          message: text,
          origin: origin,
          smsTo: smsTo,
        );
    if (wished) announcer.wished(birthday, year);
  } on WishFailure catch (failure) {
    announcer.failed(failure);
  } finally {
    keepAlive.close();
    linksAlive.close();
  }
}

/// Appelle [birthday], reliée à son contact : le composeur s'ouvre avec son
/// numéro, et l'appel compte comme vœu, avec « Annuler ».
Future<void> callToWish(BuildContext context, Birthday birthday) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final number = container.read(contactLinkProvider(birthday.id))?.number;
  if (number == null) return;
  final announcer = _WishAnnouncer.of(context, container);
  final year = birthday.wishYear(container.read(todayProvider));
  final keepAlive = container.listen(birthdayWisherProvider, (_, _) {});
  try {
    final called = await container
        .read(birthdayWisherProvider.notifier)
        .dial(birthdayId: birthday.id, year: year, number: number);
    if (called) announcer.wished(birthday, year);
  } on WishFailure catch (failure) {
    announcer.failed(failure);
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

  /// La feuille de partage, ou le composeur, ne s'est pas ouvert.
  void failed(WishFailure failure) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          WishFailure.shareUnavailable => l10n.errorSharing,
          WishFailure.dialUnavailable => l10n.contactAppUnavailable,
        }),
      ),
    );
}

/// Rectangle du bouton touché, où pointe la feuille de partage sur iPad
/// (`wishBirthday`).
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
