import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les années où la personne a été souhaitée, en pastilles menthe de la plus
/// récente à la plus ancienne. Celle de l'anniversaire en cours
/// ([BirthdayWishes.wishYear]) se retire par son ×, avec « Annuler ». Les
/// années manquées ne sont jamais montrées : pas de série à tenir. Rien
/// quand elle n'a jamais été souhaitée.
class WishYears extends StatelessWidget {
  const WishYears({super.key, required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final success = context.ankiColors.success;
    final years = [...birthday.wishedYears]..sort((a, b) => b - a);
    if (years.isEmpty) return const SizedBox.shrink();
    final current = birthday.wishYear(today);

    // La section à part, ses enfants lus dans l'ordre : le titre, puis les
    // années.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un nœud à lui : le titre seul est un en-tête, pas la section.
          Semantics(
            container: true,
            header: true,
            child: Text(l10n.personWishes, style: textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final year in years)
                Chip(
                  avatar: Icon(Icons.check_rounded, color: success.onContainer),
                  label: Text(
                    '$year',
                    semanticsLabel: l10n.personWishedIn(year),
                  ),
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: success.onContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  color: WidgetStatePropertyAll(success.container),
                  side: BorderSide.none,
                  onDeleted: year == current
                      ? () => _unwish(context, year)
                      : null,
                  deleteIcon: const Icon(Icons.close_rounded),
                  deleteIconColor: success.onContainer,
                  deleteButtonTooltipMessage: l10n.personWishRemoveYear(year),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Retire le vœu de [year], avec « Annuler » qui le remet.
  void _unwish(BuildContext context, int year) {
    // Lu maintenant : la pastille disparaît avec le vœu.
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = context.l10n;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      container
          .read(birthdayEditorProvider.notifier)
          .unmarkWished(birthday.id, year),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.personWishRemoved(year)),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          duration: accessible ? undoDelay * 2 : undoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(
              container
                  .read(birthdayEditorProvider.notifier)
                  .markWished(birthday.id, year),
            ),
          ),
        ),
      );
  }
}
