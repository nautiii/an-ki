import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/isbn_lookup.dart';
import 'package:an_ki/features/books/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner d'ISBN, page poussée au-dessus de l'onglet Livres : la caméra ne
/// tourne que tant qu'elle est ouverte. Un livre à la fois : le code lu, la
/// fiche du livre s'ouvre, « Ajouter » l'écrit sur l'étagère, la lecture
/// reprend à la fermeture de la fiche.
///
/// Caméra refusée ou indisponible : un état à nous, traduit, avec de quoi la
/// rouvrir, à la place du message anglais du paquet.
class BookScannerScreen extends ConsumerStatefulWidget {
  const BookScannerScreen({super.key});

  @override
  ConsumerState<BookScannerScreen> createState() => _BookScannerScreenState();
}

class _BookScannerScreenState extends ConsumerState<BookScannerScreen> {
  /// Les livres portent un EAN-13 : la caméra ne lit que ce format.
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
  );
  bool _isProcessing = false;

  /// Au retour des réglages du téléphone, la caméra refusée est réessayée :
  /// le paquet ne le fait pas de lui-même.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      final code = controller.value.error?.errorCode;
      if (code == MobileScannerErrorCode.permissionDenied) {
        unawaited(_startCamera());
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(controller.dispose());
    super.dispose();
  }

  /// Démarre la caméra ; un démarrage déjà en cours (double toucher) ou un
  /// refus lève une exception que l'état d'erreur du lecteur montre déjà.
  Future<void> _startCamera() async {
    try {
      await controller.start();
    } on MobileScannerException {
      // L'état d'erreur du lecteur (errorBuilder) l'affiche.
    }
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

    setState(() => _isProcessing = true);
    unawaited(_processIsbn(isbn));
  }

  Future<void> _processIsbn(String isbn) async {
    await controller.stop();
    if (!mounted) return;

    try {
      final volume = await ref.read(isbnLookupProvider.notifier).lookUp(isbn);
      if (!mounted) return;
      if (volume != null) {
        unawaited(_showBookInfo(volume));
      } else {
        _showMessage(context.l10n.bookNotFound);
        unawaited(_resetScanning());
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(switch (error) {
        BookFailure.quotaExceeded => context.l10n.errorQuotaExceeded,
        BookFailure.network => context.l10n.errorNetwork,
        _ => context.l10n.errorUnknown,
      });
      unawaited(_resetScanning());
    }
  }

  Future<void> _resetScanning() async {
    await _startCamera();
    if (mounted) setState(() => _isProcessing = false);
  }

  /// Le scan reprend à la fermeture de la fiche, livre ajouté ou non
  /// (glissée vers le bas, toucher hors de la feuille, retour).
  Future<void> _showBookInfo(IdentifiedVolume volume) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BookInfoSheet(volume: volume),
    );
    if (mounted) await _resetScanning();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // Un ajout qui échoue plus tard est annoncé par l'étagère, ouverte
    // dessous (elle écoute l'éditeur).
    final isLooking = ref.watch(
      isbnLookupProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanBook)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: ClipRSuperellipse(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.lg)),
            child: MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(
                denied:
                    error.errorCode == MobileScannerErrorCode.permissionDenied,
                onRetry: () => unawaited(_startCamera()),
                onOpenSettings: () => unawaited(
                  ref.read(contactsServiceProvider).openAppSettings(),
                ),
              ),
              overlayBuilder: (context, _) => _Viewfinder(
                busy: _isProcessing || isLooking,
                hint: l10n.scanHint,
                colorScheme: colorScheme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viseur clair sur l'image de la caméra, quel que soit le thème (les rôles
/// « fixed » ne changent pas en sombre), et la consigne dessous.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.busy,
    required this.hint,
    required this.colorScheme,
  });

  final bool busy;
  final String hint;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.sm),
                ),
                side: BorderSide(color: colorScheme.primaryFixed, width: 2),
              ),
            ),
            child: const SizedBox(width: 240, height: 144),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.scrim.withValues(alpha: 0.6),
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.primaryFixed),
                ),
              ),
            ),
          ),
        ),
        if (busy)
          ColoredBox(
            color: colorScheme.scrim.withValues(alpha: 0.45),
            child: Center(
              child: CircularProgressIndicator(color: colorScheme.primaryFixed),
            ),
          ),
      ],
    );
  }
}

/// La caméra ne démarre pas : refusée (l'autoriser, ou ouvrir les réglages
/// de l'app quand Android ne redemande plus), ou indisponible (réessayer).
class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.denied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool denied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: AnKiEmptyState(
            illustration: Icon(
              denied
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              size: AppSpacing.xxl,
              color: colorScheme.onSurfaceVariant,
            ),
            title: denied
                ? l10n.cameraDeniedTitle
                : l10n.cameraUnavailableTitle,
            message: denied
                ? l10n.cameraDeniedMessage
                : l10n.cameraUnavailableMessage,
            primaryLabel: denied ? l10n.cameraAllow : l10n.retry,
            primaryIcon: denied
                ? Icons.photo_camera_outlined
                : Icons.refresh_rounded,
            onPrimary: onRetry,
            secondaryLabel: denied ? l10n.openAppSettings : null,
            onSecondary: denied ? onOpenSettings : null,
          ),
        ),
      ),
    );
  }
}
