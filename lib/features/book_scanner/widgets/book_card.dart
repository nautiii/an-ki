import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:flutter/material.dart';

/// Livre gardé : couverture, titre, auteurs, ISBN et année de parution.
class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final imageUrl = book.imageUrl;
    final publishedDate = book.publishedDate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.surfaceContainerHigh,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.lg)),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRSuperellipse(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.sm),
                ),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: _PlaceholderCover.size.width,
                        height: _PlaceholderCover.size.height,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _PlaceholderCover(),
                      )
                    : const _PlaceholderCover(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                // Centré dans la carte ; en grand texte, il défile plutôt que
                // de déborder de la hauteur du carrousel.
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book.title,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (book.authors.isNotEmpty)
                          Text(
                            book.authors.join(', '),
                            style: muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(context.l10n.isbnLabel(book.isbn), style: muted),
                        if (publishedDate != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            publishedDate,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  /// Format de la couverture, celui d'un livre de poche.
  static const Size size = Size(60, 90);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.book_rounded, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
