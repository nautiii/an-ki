import 'dart:typed_data';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/quick_birthday.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_photo_button.dart';
import 'package:flutter/material.dart';

/// Ce qu'AnKi a compris d'une ligne prête : l'avatar (qui choisit une
/// photo), le nom, « Le 12 mars » ou « Le 17 novembre 1990 · aura 36 ans »,
/// et un avertissement si la personne est déjà là.
class QuickLinePreview extends StatelessWidget {
  const QuickLinePreview({
    super.key,
    required this.line,
    required this.today,
    required this.known,
    required this.picture,
    required this.onPickPhoto,
  });

  /// Une ligne prête ([QuickBirthday.isReady]).
  final QuickBirthday line;
  final DateTime today;

  /// La même personne est déjà dans AnKi ([isKnownBirthday]) : l'ajout reste
  /// possible (des homonymes nés le même jour existent).
  final bool known;
  final Uint8List? picture;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final date = (line.date as BirthDateComplete).date;
    final words = date.formatted(context);
    final dateLine = switch (date.turningAge(today)) {
      final age? => l10n.birthDatePreviewAge(words, age),
      null => l10n.birthDatePreview(words),
    };

    return _Panel(
      child: Row(
        children: [
          BirthdayPhotoButton(
            name: line.fullName,
            picture: picture,
            onTap: onPickPhoto,
            radius: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            // Lu par TalkBack dès que la ligne est comprise : ce qu'AnKi va
            // enregistrer, sans regarder l'écran.
            child: Semantics(
              liveRegion: true,
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.fullName, style: textTheme.titleMedium),
                    Text(
                      dateLine,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (known) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      // Un avertissement, pas une erreur : l'ajout reste permis.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.people_alt_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Text(
                              l10n.quickAddKnown(line.fullName),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une liste collée : combien seront ajoutés, puis chaque ligne, ajoutée ou
/// écartée avec sa raison (le texte la dit, l'icône la souligne).
class QuickBatchPreview extends StatelessWidget {
  const QuickBatchPreview({super.key, required this.batch});

  final QuickBatch batch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    String dateOf(QuickBirthday line) => switch (line.date) {
      BirthDateComplete(:final date) => l10n.birthDatePreview(
        date.formatted(context),
      ),
      _ => '',
    };

    String reasonOf(QuickBirthday line) => switch (line.date) {
      BirthDateComplete() => l10n.quickAddBatchNoName,
      BirthDateInvalid() || BirthDateIncomplete() => l10n.quickAddBatchBadDate,
      BirthDateEmpty() => l10n.quickAddBatchNoDate,
    };

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quickAddBatchTitle(batch.fresh.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final line in batch.fresh)
            _BatchRow(
              icon: Icons.check_circle_rounded,
              color: colorScheme.primary,
              name: line.fullName,
              detail: dateOf(line),
            ),
          for (final line in batch.known)
            _BatchRow(
              icon: Icons.people_alt_outlined,
              color: colorScheme.onSurfaceVariant,
              name: line.fullName,
              detail: l10n.quickAddBatchKnown,
            ),
          for (final line in batch.unreadable)
            _BatchRow(
              icon: Icons.error_outline_rounded,
              color: colorScheme.error,
              // Sans nom, la ligne telle que tapée dit laquelle est écartée.
              name: line.fullName.isEmpty ? line.source : line.fullName,
              detail: reasonOf(line),
            ),
        ],
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({
    required this.icon,
    required this.color,
    required this.name,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name, style: textTheme.titleSmall),
                  TextSpan(
                    text: ' · $detail',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fond discret des aperçus, sous le champ.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: child,
      ),
    );
  }
}
