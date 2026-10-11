import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/providers/book_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fiche d'un livre scanné : couverture, titre, auteurs, et « Ajouter ».
///
/// Se ferme d'elle-même après l'ajout ; l'appelant reprend le scan quelle
/// que soit la façon dont la feuille se ferme.
class BookInfoSheet extends ConsumerWidget {
  const BookInfoSheet({super.key, required this.book});

  final Book book;

  static const _coverSize = Size(80, 120);
  static const _coverRadius = BorderRadius.all(Radius.circular(AppRadii.xs));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = book.imageUrl;
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
                        book.title,
                        style: textTheme.titleLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.authors.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          book.authors.join(', '),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      if (book.publishedDate != null)
                        Text(
                          book.publishedDate!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        context.l10n.isbnLabel(book.isbn),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (book.description != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                book.description!,
                style: textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Écriture optimiste : on ferme tout de suite, l'écran du
                // scanner annonce un échec éventuel.
                onPressed: () {
                  unawaited(ref.read(bookEditorProvider.notifier).save(book));
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
