import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions du héros le jour J : dire que l'anniversaire est souhaité, puis la
/// pastille menthe « ✓ Souhaité » à leur place, à la même hauteur : la carte
/// ne saute pas.
class WishActions extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (wished) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: _WishedPill(),
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => markWishedWithUndo(context, birthday),
          style: TextButton.styleFrom(foregroundColor: onColor),
          child: Text(context.l10n.alreadyWished),
        ),
      ],
    );
  }
}

/// « ✓ Souhaité » en menthe (accent de succès), haute comme une cible
/// tactile.
class _WishedPill extends StatelessWidget {
  const _WishedPill();

  @override
  Widget build(BuildContext context) {
    final success = context.ankiColors.success;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: success.container,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 18, color: success.onContainer),
              const SizedBox(width: AppSpacing.xs),
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
      ),
    );
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
  _announceWished(context, container, birthday, year);
}

/// Confirme le vœu (vibration légère, snackbar) et propose de l'annuler :
/// l'année retirée est celle marquée, même si minuit passe entre-temps.
void _announceWished(
  BuildContext context,
  ProviderContainer container,
  Birthday birthday,
  int year,
) {
  final l10n = context.l10n;
  final accessible = MediaQuery.accessibleNavigationOf(context);

  unawaited(HapticFeedback.lightImpact());
  ScaffoldMessenger.of(context)
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
