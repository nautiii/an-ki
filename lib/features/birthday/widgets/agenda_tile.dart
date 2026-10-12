import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/moon_phase.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Ligne d'agenda : qui, quand, quel âge. L'anneau de l'avatar porte les
/// couleurs des catégories de la personne.
///
/// Toucher ouvre la modification. Glisser vers la gauche, ou l'action
/// « Supprimer » des lecteurs d'écran, supprime avec « Annuler ».
class AgendaTile extends ConsumerWidget {
  const AgendaTile({super.key, required this.birthday});

  final Birthday birthday;

  static const _radius = BorderRadius.all(Radius.circular(AppRadii.lg));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRSuperellipse(
      borderRadius: _radius,
      child: Dismissible(
        key: Key(birthday.id),
        // La droite reste libre pour une action positive (« Souhaiter »).
        direction: DismissDirection.endToStart,
        onDismissed: (_) => deleteWithUndo(context, birthday),
        background: ColoredBox(
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Icon(
                Icons.delete_outline_rounded,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: MergeSemantics(
            child: Semantics(
              button: true,
              customSemanticsActions: {
                CustomSemanticsAction(label: context.l10n.delete): () =>
                    deleteWithUndo(context, birthday),
              },
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  BirthdayFormSheet.show(context, birthdayToEdit: birthday);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _TileContent(birthday: birthday),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileContent extends ConsumerWidget {
  const _TileContent({required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final today = ref.watch(todayProvider);
    final days = birthday.daysUntilNext(today);
    final date = DateFormat.MMMMd(locale)
        .format(birthday.nextOccurrence(today));
    final fullName = birthday.fullName;
    final picture = birthday.picture;

    final categories = birthday.categoriesFrom(
      ref.watch(categoriesProvider).value ?? const [],
    );

    // L'anneau est muet pour TalkBack : les catégories sont lues en clair.
    final avatar = Semantics(
      label: [
        for (final category in categories) category.localizedName(context),
      ].join(', '),
      child: AnKiAvatar(
        name: fullName,
        image: picture != null ? MemoryImage(picture) : null,
        ringColors: [
          for (final category in categories) category.tones(context).color,
        ],
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fullName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
        ),
        Text(
          // Sans année de naissance, la date seule : aucun âge inventé.
          switch (birthday.turningAge(today)) {
            final age? => context.l10n.agendaLine(date, age),
            null => date,
          },
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final countdown = _Countdown(days: days);

    // Grand texte : avatar et compte à rebours au-dessus, le texte en dessous.
    if (MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [avatar, const Spacer(), countdown]),
          const SizedBox(height: AppSpacing.xs),
          identity,
        ],
      );
    }
    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: identity),
        const SizedBox(width: AppSpacing.xs),
        countdown,
      ],
    );
  }
}

/// Lune et pastille « J-12 » : la proximité d'un coup d'œil.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoonPhase(daysLeft: days, size: 18),
        const SizedBox(width: AppSpacing.xs),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colorScheme.secondaryContainer,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              context.l10n.countdownDays(days),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
