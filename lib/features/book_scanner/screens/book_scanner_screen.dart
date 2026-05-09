import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/book_scanner/models/book_model.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
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

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isProcessing = true;
        });

        // On arrête immédiatement le scanner pour éviter les appels multiples
        await controller.stop();

        final isbn = barcode.rawValue!;
        await ref.read(bookScannerProvider.notifier).scanIsbn(isbn);

        if (mounted) {
          final bookState = ref.read(bookScannerProvider);
          if (bookState.hasValue && bookState.value != null) {
            _showBookInfo(bookState.value!);
          } else {
            _showErrorSnippet(context.l10n.bookNotFound);
            // Si non trouvé, on redémarre le scanner pour permettre un autre essai
            await controller.start();
            setState(() {
              _isProcessing = false;
            });
          }
        }
        break;
      }
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
