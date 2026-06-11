import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/book_model.dart';
import 'package:an_ki/data/repositories/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/widgets/book_card.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BookScannerScreen extends ConsumerStatefulWidget {
  const BookScannerScreen({super.key});

  @override
  ConsumerState<BookScannerScreen> createState() => _BookScannerScreenState();
}

class _BookScannerScreenState extends ConsumerState<BookScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
    });

    _processIsbn(barcode.rawValue!);
  }

  Future<void> _processIsbn(String isbn) async {
    await controller.stop();

    if (!mounted) return;

    try {
      final book = await ref.read(bookScannerProvider.notifier).scanIsbn(isbn);
      if (mounted) {
        if (book != null) {
          _showBookInfo(book);
        } else {
          _showErrorSnippet(context.l10n.bookNotFound);
          _resetScanning();
        }
      }
    } catch (error) {
      if (mounted) {
        if (error is GoogleBooksQuotaExceededException) {
          _showErrorSnippet(context.l10n.errorQuotaExceeded);
        } else {
          _showErrorSnippet(context.l10n.bookNotFound);
        }
        _resetScanning();
      }
    }
  }

  Future<void> _resetScanning() async {
    await controller.start();
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showBookInfo(BookModel book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => BookInfoSheet(
            book: book,
            onClosed: () async {
              await _resetScanning();
            },
          ),
    );
  }

  void _showErrorSnippet(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bookState = ref.watch(bookScannerProvider);
    final books = bookState.savedBooks;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Header(showViewToggle: false),
              const SizedBox(height: 24),

              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: controller,
                        onDetect: _onDetect,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 200,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_isProcessing || bookState.isScanning)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const _CategoryPlaceholders(),

              const SizedBox(height: 24),

              Expanded(
                child:
                    bookState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : books.isEmpty
                        ? Center(
                          child: Text(
                            context.l10n.noBirthdaysFound,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mes Livres',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: PageView.builder(
                                itemCount: books.length,
                                controller: PageController(
                                  viewportFraction: 0.85,
                                ),
                                padEnds: false,
                                itemBuilder: (context, index) {
                                  return BookCard(book: books[index]);
                                },
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPlaceholders extends StatelessWidget {
  const _CategoryPlaceholders();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(context, 'Roman', Icons.menu_book_rounded),
          _buildChip(context, 'BD', Icons.palette_rounded),
          _buildChip(context, 'Cuisine', Icons.restaurant_rounded),
          _buildChip(context, 'Tech', Icons.computer_rounded),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        avatar: Icon(icon, size: 16, color: colorScheme.primary),
        backgroundColor: colorScheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
