import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/book_scanner/models/book_model.dart';
import 'package:flutter/material.dart';

class BookInfoSheet extends StatelessWidget {
  const BookInfoSheet({super.key, required this.book, required this.onClosed});

  final BookModel book;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            context.l10n.bookTitle,
            style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            book.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ISBN: ${book.isbn}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onClosed();
              },
              child: Text(context.l10n.validate),
            ),
          ),
        ],
      ),
    );
  }
}
