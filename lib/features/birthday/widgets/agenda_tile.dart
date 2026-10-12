import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/moon_phase.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
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
/// Toucher ouvre la modification. Glisser vers la droite, ou l'action
/// « Supprimer » des lecteurs d'écran, supprime après confirmation.
class AgendaTile extends ConsumerWidget {
  const AgendaTile({super.key, required this.birthday});

  final Birthday birthday;

  static const _radius = BorderRadius.all(Radius.circular(AppRadii.lg));

  String get _fullName => '${birthday.name} ${birthday.surname}';

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteBirthdayTitle),
        content: Text(context.l10n.deleteBirthdayConfirmation(_fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _delete(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(birthdayEditorProvider.notifier).delete(birthday.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.birthdayDeleted(_fullName))),
    );
  }

  /// Chemin des lecteurs d'écran, sans glissement : même confirmation.
  Future<void> _confirmThenDelete(BuildContext context, WidgetRef ref) async {
    if (await _confirmDelete(context) && context.mounted) {
      _delete(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRSuperellipse(
      borderRadius: _radius,
      child: Dismissible(
        key: Key(birthday.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) {
          unawaited(HapticFeedback.mediumImpact());
          return _confirmDelete(context);
        },
        onDismissed: (_) => _delete(context, ref),
        background: ColoredBox(
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
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
                    unawaited(_confirmThenDelete(context, ref)),
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
    final fullName = '${birthday.name} ${birthday.surname}';
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
          context.l10n.agendaLine(
            DateFormat.MMMMd(locale).format(birthday.nextOccurrence(today)),
            birthday.turningAge(today),
          ),
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
