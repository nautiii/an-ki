import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/book_scanner/models/book_model.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/repositories/book_repository.dart';
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
    // On arrête immédiatement le scanner pour éviter les appels multiples au niveau natif
    await controller.stop();

    if (!mounted) return;

    await ref.read(bookScannerProvider.notifier).scanIsbn(isbn);

    if (mounted) {
      final bookState = ref.read(bookScannerProvider);

      bookState.when(
        data: (book) {
          if (book != null) {
            _showBookInfo(book);
          } else {
            _showErrorSnippet(context.l10n.bookNotFound);
            _resetScanning();
          }
        },
        loading: () {},
        error: (error, stack) {
          if (error is GoogleBooksQuotaExceededException) {
            _showErrorSnippet(context.l10n.errorQuotaExceeded);
          } else {
            _showErrorSnippet(context.l10n.bookNotFound);
          }
          _resetScanning();
        },
      );
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
              // On redémarre le scanner quand la modale est fermée
              await controller.start();
              setState(() {
                _isProcessing = false;
              });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bookScannerTitle),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          // Overlay to show scanning area
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
