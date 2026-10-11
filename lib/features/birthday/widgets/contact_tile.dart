import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tuile d'une personne : avatar, nom, date, catégories et âge.
///
/// Toucher ouvre la modification. Glisser vers la droite, ou l'action
/// « Supprimer » des lecteurs d'écran, supprime après confirmation.
class ContactTile extends ConsumerWidget {
  const ContactTile({super.key, required this.birthday});

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
    final today = ref.watch(todayProvider);
    // Les puces sont un complément : sans catégories chargées, la tuile reste lisible.
    final allCategories = ref.watch(categoriesProvider).value ?? const [];
    final categories = allCategories
        .where((category) => birthday.categories.contains(category.id))
        .toList();
    final picture = birthday.picture;
    final fullName = '${birthday.name} ${birthday.surname}';

    final avatar = AnKiAvatar(
      name: fullName,
      image: picture != null ? MemoryImage(picture) : null,
    );
    final details = Column(
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
          birthday.formattedDate(context),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final category in categories)
                _CategoryChip(category: category),
            ],
          ),
        ],
      ],
    );
    final age = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${birthday.ageOn(today)}',
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          context.l10n.yearsOld,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    // Grand texte : avatar et âge passent au-dessus, le texte prend la largeur.
    final reflow = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    if (reflow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [avatar, const Spacer(), age]),
          const SizedBox(height: AppSpacing.xs),
          details,
        ],
      );
    }
    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: details),
        const SizedBox(width: AppSpacing.xs),
        age,
      ],
    );
  }
}

/// Puce de catégorie : icône et libellé sur la teinte tonale de la catégorie.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final BirthdayCategory category;

  @override
  Widget build(BuildContext context) {
    final tones = category.tones(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tones.container,
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
            Icon(category.iconData, size: 16, color: tones.onContainer),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                category.localizedName(context),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: tones.onContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
