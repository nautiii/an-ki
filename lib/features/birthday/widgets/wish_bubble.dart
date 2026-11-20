import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/wish_message_section.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le message qu'enverra « Souhaiter », en entier dans une bulle : le
/// premier vœu suggéré. La toucher ouvre [OtherWishesSheet] (⌄, « Choisir
/// un autre message »). [fill] et [onFill] dépendent de la surface : voile
/// de fête sur le héros, nuage ailleurs.
class WishBubble extends ConsumerWidget {
  const WishBubble({
    super.key,
    required this.birthday,
    required this.fill,
    required this.onFill,
  });

  final Birthday birthday;
  final Color fill;
  final Color onFill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = wishTexts(
      l10n,
      birthday.name,
      ref.watch(wishSuggestionsProvider(birthday)),
    ).first;
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );
    const shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
    );

    return Semantics(
      button: true,
      enabled: !sharing,
      hint: l10n.wishChooseAnother,
      child: Material(
        color: fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: sharing
              ? null
              : () => unawaited(OtherWishesSheet.show(context, birthday)),
          splashColor: onFill.withValues(alpha: 0.12),
          highlightColor: onFill.withValues(alpha: 0.08),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: onFill),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ExcludeSemantics(
                    child: Icon(Icons.expand_more_rounded, color: onFill),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les trois vœux suggérés : en toucher un l'envoie aussitôt par la feuille
/// de partage ; en bas, écrire le sien (il passera ensuite en premier).
class OtherWishesSheet extends ConsumerWidget {
  const OtherWishesSheet({
    super.key,
    required this.birthday,
    required this.onWish,
    required this.onWrite,
  });

  final Birthday birthday;

  /// Envoie le message touché ; la feuille est déjà fermée.
  final ValueChanged<String> onWish;

  /// Ouvre le message propre à la personne ; la feuille est déjà fermée.
  final VoidCallback onWrite;

  /// Ouvre la feuille au-dessus des onglets, depuis [context] (la bulle).
  ///
  /// Le vœu part du contexte de la feuille, pas de la bulle : celle-ci peut
  /// disparaître pendant que la feuille est ouverte (minuit, vœu fait sur un
  /// autre appareil). La route reste montée pendant sa sortie, et
  /// `wishBirthday` lit tout avant d'attendre ; le conteneur, le messager et
  /// le navigateur racines sont les mêmes. L'origine du partage (iPad) est
  /// celle de la bulle, prise tant qu'elle est là.
  static Future<void> show(BuildContext context, Birthday birthday) {
    final origin = shareOriginOf(context);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => OtherWishesSheet(
        birthday: birthday,
        onWish: (message) {
          Navigator.pop(sheetContext);
          unawaited(
            wishBirthday(
              sheetContext,
              birthday,
              message: message,
              origin: origin,
            ),
          );
        },
        onWrite: () {
          Navigator.pop(sheetContext);
          unawaited(WishMessageSheet.show(sheetContext, birthday));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final texts = wishTexts(
      l10n,
      birthday.name,
      ref.watch(wishSuggestionsProvider(birthday)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.wishOtherMessages,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final text in texts) ...[
            Card(
              margin: EdgeInsets.zero,
              color: scheme.primaryContainer,
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                button: true,
                hint: l10n.wish,
                child: InkWell(
                  onTap: () => onWish(text),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractiveDimension,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.send_rounded,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onWrite,
              icon: const Icon(Icons.edit_rounded),
              label: Text(l10n.wishWriteOwn(birthday.name)),
            ),
          ),
        ],
      ),
    );
  }
}
