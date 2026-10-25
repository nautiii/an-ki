import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:an_ki/features/book_scanner/providers/book_editor.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/providers/isbn_lookup.dart';
import 'package:an_ki/features/book_scanner/widgets/book_card.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BookScannerScreen extends ConsumerStatefulWidget {
  const BookScannerScreen({super.key});

  @override
  ConsumerState<BookScannerScreen> createState() => _BookScannerScreenState();
}

class _BookScannerScreenState extends ConsumerState<BookScannerScreen> {
  /// Hauteur du carrousel de livres, reprise par son squelette.
  static const double _bookCardHeight = 180;

  final MobileScannerController controller = MobileScannerController();
  final PageController _booksController = PageController(
    viewportFraction: 0.85,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    _booksController.dispose();
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
      final book = await ref.read(isbnLookupProvider.notifier).lookUp(isbn);
      if (mounted) {
        if (book != null) {
          unawaited(_showBookInfo(book));
        } else {
          _showErrorSnippet(context.l10n.bookNotFound);
          unawaited(_resetScanning());
        }
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnippet(switch (error) {
          BookFailure.quotaExceeded => context.l10n.errorQuotaExceeded,
          _ => context.l10n.bookNotFound,
        });
        unawaited(_resetScanning());
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

  /// Le scan reprend à la fermeture de la fiche, livre ajouté ou non
  /// (glissée vers le bas, toucher hors de la feuille, retour).
  Future<void> _showBookInfo(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BookInfoSheet(book: book),
    );
    if (mounted) await _resetScanning();
  }

  void _showErrorSnippet(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // L'ajout d'un livre est optimiste (la feuille se ferme sans attendre) :
    // l'écran, toujours monté dessous, annonce un échec tardif.
    ref.listen(bookEditorProvider, (_, next) {
      if (next is AsyncError) _showErrorSnippet(context.l10n.errorUnknown);
    });
    final savedBooks = ref.watch(savedBooksProvider);
    final isLoading =
        savedBooks.isLoading && !savedBooks.hasValue && !savedBooks.hasError;
    final isScanning = ref.watch(isbnLookupProvider.select((s) => s.isLoading));
    final books = savedBooks.value ?? const <Book>[];
    final profileLoaded = ref.watch(
      userProfileProvider.select((profile) => profile.hasValue),
    );
    final greetingName = ref.watch(greetingNameProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Header(
                greeting: context.l10n.greeting(
                  ref.watch(greetingProvider).name,
                ),
                // Squelette tant que le profil charge ; ensuite le prénom, ou
                // rien pour un invité.
                userName: profileLoaded ? greetingName ?? '' : null,
                onOpenSettings: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(height: AppSpacing.lg),

              ClipRSuperellipse(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.lg),
                ),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: controller,
                        onDetect: _onDetect,
                      ),
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(AppRadii.lg),
                            ),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      // Viseur clair sur l'image de la caméra, quel que soit
                      // le thème : les rôles « fixed » ne changent pas en sombre.
                      Center(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: RoundedSuperellipseBorder(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(AppRadii.sm),
                              ),
                              side: BorderSide(
                                color: colorScheme.primaryFixed,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const SizedBox(width: 200, height: 120),
                        ),
                      ),
                      if (_isProcessing || isScanning)
                        ColoredBox(
                          color: colorScheme.scrim.withValues(alpha: 0.45),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primaryFixed,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bookScannerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: isLoading
                          ? const Align(
                              alignment: Alignment.topLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.85,
                                child: SkeletonBox(
                                  height: _bookCardHeight,
                                  radius: AppRadii.lg,
                                ),
                              ),
                            )
                          : books.isEmpty
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl,
                              ),
                              child: AnKiEmptyState(
                                illustration: Image.asset(AppAssets.moon),
                                title: context.l10n.noBooksYet,
                                message: context.l10n.noBooksMessage,
                              ),
                            )
                          : SizedBox(
                              height: _bookCardHeight,
                              child: PageView.builder(
                                itemCount: books.length,
                                controller: _booksController,
                                padEnds: false,
                                itemBuilder: (context, index) {
                                  return BookCard(book: books[index]);
                                },
                              ),
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
