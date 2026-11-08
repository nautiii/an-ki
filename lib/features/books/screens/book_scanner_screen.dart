import 'dart:async';
import 'dart:math' as math;

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/greeting_title.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/book.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/providers/book_editor.dart';
import 'package:an_ki/features/books/providers/book_scanner_provider.dart';
import 'package:an_ki/features/books/providers/isbn_lookup.dart';
import 'package:an_ki/features/books/widgets/book_card.dart';
import 'package:an_ki/features/books/widgets/book_info_sheet.dart';
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
  /// Hauteur du carrousel de livres au texte normal, reprise par son squelette.
  static const double _bookCardHeight = 180;

  /// Les livres portent un EAN-13 : la caméra ne lit que ce format.
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
  );
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

    // Un code qui n'est pas un ISBN (produit, QR) est ignoré, sans message :
    // la caméra le relirait en boucle.
    final isbn = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .nonNulls
        .where(isBookIsbn)
        .firstOrNull;
    if (isbn == null) return;

    setState(() {
      _isProcessing = true;
    });

    _processIsbn(isbn);
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
          BookFailure.network => context.l10n.errorNetwork,
          _ => context.l10n.errorUnknown,
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
    final l10n = context.l10n;
    final period = ref.watch(greetingProvider).name;
    // Sans nom (invité, profil pas encore chargé) : la salutation seule.
    final name = ref.watch(greetingNameProvider);
    final greeting = l10n.greeting(period);
    // La carte grandit comme son petit texte : à 200 %, titre, ISBN et date
    // tiennent. Le facteur vient d'une taille de police réelle, car l'échelle
    // d'Android 14+ n'est pas linéaire (scale(180) ne grandirait presque pas).
    final cardFontSize = Theme.of(context).textTheme.bodySmall?.fontSize ?? 12;
    final bookCardHeight =
        _bookCardHeight *
        math.max(
          1,
          MediaQuery.textScalerOf(context).scale(cardFontSize) / cardFontSize,
        );

    return Scaffold(
      // Même barre épinglée que l'accueil, réglages compris.
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        titleSpacing: AppSpacing.gutter,
        toolbarHeight: GreetingTitle.toolbarHeight(context),
        title: GreetingTitle(
          greeting: greeting,
          name: name,
          oneLine: name == null ? greeting : l10n.greetingName(period, name),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: l10n.settings,
            icon: AnKiAvatar(name: name ?? '', radius: 16),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      // Un seul défilement, jusqu'au-dessus de la barre flottante : sur un
      // petit écran en grand texte, la carte du livre reste entière.
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

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

              Text(
                context.l10n.bookScannerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              if (isLoading)
                FractionallySizedBox(
                  widthFactor: 0.85,
                  child: SkeletonBox(
                    height: bookCardHeight,
                    radius: AppRadii.lg,
                  ),
                )
              else if (books.isEmpty)
                AnKiEmptyState(
                  illustration: Image.asset(AppAssets.moon),
                  title: context.l10n.noBooksYet,
                  message: context.l10n.noBooksMessage,
                )
              else
                SizedBox(
                  height: bookCardHeight,
                  child: PageView.builder(
                    itemCount: books.length,
                    controller: _booksController,
                    padEnds: false,
                    itemBuilder: (context, index) {
                      return BookCard(book: books[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
