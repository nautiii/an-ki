import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fiche d'un livre scanné : couverture, titre, auteurs, et « Ajouter ».
///
/// Se ferme d'elle-même après l'ajout ; l'appelant reprend le scan quelle
/// que soit la façon dont la feuille se ferme.
class BookInfoSheet extends ConsumerWidget {
  const BookInfoSheet({super.key, required this.volume});

  /// Le livre scanné, identifié par les catalogues.
  final IdentifiedVolume volume;

  static const _coverSize = Size(80, 120);
  static const _coverRadius = BorderRadius.all(Radius.circular(AppRadii.xs));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metadata = volume.metadata;
    final imageUrl = metadata.imageUrl;
    final title = volumeTitleOf(metadata);
    final publishedDate = metadata.publishedDate;
    const coverShape = RoundedSuperellipseBorder(borderRadius: _coverRadius);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Couverture décorative : le titre est lu juste à côté.
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: coverShape,
                      color: colorScheme.surfaceContainerHighest,
                      shadows: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRSuperellipse(
                      borderRadius: _coverRadius,
                      child: SizedBox.fromSize(
                        size: _coverSize,
                        child: imageUrl != null
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Icon(
                                Icons.book_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 40,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.bookTitle,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        title.isEmpty ? context.l10n.bookUntitled : title,
                        style: textTheme.titleLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (metadata.authors.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          metadata.authors.join(', '),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      if (publishedDate != null)
                        Text(
                          publishedDate,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        context.l10n.isbnLabel(volume.isbn),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Écriture optimiste : on ferme tout de suite, l'écran du
                // scanner annonce un échec éventuel. Le livre est déjà
                // identifié : pas de seconde recherche.
                onPressed: () {
                  unawaited(
                    ref
                        .read(shelfEditorProvider.notifier)
                        .addScanned(volume.isbn, identified: volume),
                  );
                  Navigator.pop(context);
                },
                child: Text(context.l10n.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
