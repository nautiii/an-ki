import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/burst_list.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/isbn_entry_sheet.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner d'ISBN en rafale, page poussée au-dessus de l'onglet Livres : la
/// caméra ne tourne que tant qu'elle est ouverte, et reste ouverte d'un livre
/// à l'autre. Chaque nouveau tome est écrit aussitôt (hors ligne compris) et
/// s'empile en bas, le plus récent en haut ; une vibration légère et une
/// coche le confirment. Un tome déjà possédé le dit, sans vibrer.
///
/// Replis : la lampe, « Saisir un ISBN » ; « Terminé » revient à l'étagère.
/// Caméra refusée ou indisponible : un état à nous, traduit, avec de quoi la
/// rouvrir, à la place du message anglais du paquet.
class BookScannerScreen extends ConsumerStatefulWidget {
  const BookScannerScreen({super.key});

  @override
  ConsumerState<BookScannerScreen> createState() => _BookScannerScreenState();
}

/// Durée de « Déjà dans votre collection » : le temps de lire, pas plus.
const _ownedNoticeDuration = Duration(seconds: 2);

class _BookScannerScreenState extends ConsumerState<BookScannerScreen> {
  /// « Déjà dans votre collection » affiché ou en file ; null sinon.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _ownedNotice;

  /// Les livres portent un EAN-13 : la caméra ne lit que ce format.
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
  );

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
    // Un code qui n'est pas un ISBN (produit, QR) est ignoré, sans message :
    // la caméra le relirait en boucle.
    final burst = ref.read(burstScanProvider.notifier);
    for (final code in capture.barcodes.map((b) => b.rawValue).nonNulls) {
      if (isBookIsbn(code)) _handle(burst.scan(code));
    }
  }

  Future<void> _typeIsbn() async {
    final isbn = await IsbnEntrySheet.show(context);
    if (isbn == null || !mounted) return;
    _handle(ref.read(burstScanProvider.notifier).scan(isbn, typed: true));
  }

  /// Vibre pour un ajout ; dit « déjà dans votre collection » sans vibrer.
  /// Un code relu ou illisible ne dit rien : la caméra le relit en boucle.
  void _handle(ScanResult result) {
    switch (result) {
      case (outcome: ScanOutcome.added, row: _):
        unawaited(HapticFeedback.lightImpact());
      case (outcome: ScanOutcome.alreadyOwned, row: final row?):
        // Un seul à la fois, bref : une pile de tomes possédés ne fait pas
        // défiler des messages en retard sur la caméra. Sans masquer la
        // snackbar en cours : ce peut être l'« Annuler » d'un retrait.
        if (_ownedNotice != null) return;
        final notice = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: _ownedNoticeDuration,
            content: Text(context.l10n.burstAlreadyOwned(ownedVolumeText(row))),
          ),
        );
        _ownedNotice = notice;
        unawaited(
          notice.closed.then((_) {
            if (_ownedNotice == notice) _ownedNotice = null;
          }),
        );
      case _:
        break;
    }
  }

  /// Correction d'un tome de la rafale : « Introuvable » s'ouvre sur son
  /// classement, les autres sur leur feuille (classer, retirer).
  void _open(BurstRow row) {
    if (row.status == BurstRowStatus.notFound) {
      final volume = ref.read(volumeByIdProvider(row.isbn)).value;
      if (volume != null) {
        unawaited(ClassifySheet.show(context, volume));
        return;
      }
    }
    unawaited(VolumeSheet.show(context, row.isbn));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final rows = ref.watch(burstRowsProvider);
    final height = MediaQuery.sizeOf(context).height;

    return PendingCompleter(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scanBook),
          actions: [
            _TorchButton(controller: controller),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xs,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: ClipRSuperellipse(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadii.lg),
                    ),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) => _CameraError(
                        denied:
                            error.errorCode ==
                            MobileScannerErrorCode.permissionDenied,
                        onRetry: () => unawaited(_startCamera()),
                        onOpenSettings: () => unawaited(
                          ref.read(contactsServiceProvider).openAppSettings(),
                        ),
                      ),
                      overlayBuilder: (context, _) => _Viewfinder(
                        hint: l10n.scanHint,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
              if (rows.isNotEmpty)
                // La caméra garde la plus grande part : la liste défile.
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height * 0.4),
                  child: BurstList(rows: rows, onOpen: _open),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                // Côte à côte, ou l'un sous l'autre à 200 %.
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: AppSpacing.xs,
                  spacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => unawaited(_typeIsbn()),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: Text(l10n.isbnEntryTitle),
                    ),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: Text(l10n.scanDone),
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

/// La lampe, quand le téléphone en a une.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final torch = state.torchState;
        if (!state.isRunning || torch == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final on = torch == TorchState.on;
        return IconButton(
          onPressed: () => unawaited(controller.toggleTorch()),
          isSelected: on,
          tooltip: on ? l10n.torchOff : l10n.torchOn,
          icon: const Icon(Icons.flashlight_on_outlined),
          selectedIcon: const Icon(Icons.flashlight_on_rounded),
        );
      },
    );
  }
}

/// Viseur clair sur l'image de la caméra, quel que soit le thème (les rôles
/// « fixed » ne changent pas en sombre), et la consigne dessous.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.hint, required this.colorScheme});

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
