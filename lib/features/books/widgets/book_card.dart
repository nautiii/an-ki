import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter/material.dart';

/// Tome de l'étagère : couverture, titre, auteurs, ISBN et date de parution.
class BookCard extends StatelessWidget {
  final Volume volume;

  const BookCard({super.key, required this.volume});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final imageUrl = volume.imageUrl;
    final publishedDate = volume.publishedDate;
    final isbn = volume.isbn;

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
                          volume.title.isEmpty
                              ? context.l10n.bookUntitled
                              : volume.title,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (volume.authors.isNotEmpty)
                          Text(
                            volume.authors.join(', '),
                            style: muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (isbn != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(context.l10n.isbnLabel(isbn), style: muted),
                        ],
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
