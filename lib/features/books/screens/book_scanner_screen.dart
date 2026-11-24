import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/burst_ticket.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/glass_circle.dart';
import 'package:an_ki/features/books/widgets/isbn_entry_sheet.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner d'ISBN en rafale, page poussée au-dessus de l'onglet Livres,
/// toujours en sombre : la caméra ne tourne que tant qu'elle est ouverte, et
/// reste ouverte d'un livre à l'autre. Chaque nouveau tome est écrit aussitôt
/// (hors ligne compris) et entre dans le ticket « Cette session », rangé par
/// série ; une vibration légère le confirme. Un tome déjà possédé le dit,
/// sans vibrer.
///
/// Replis : la lampe, « Saisir un ISBN » ; « Terminé » revient à l'étagère.
/// Caméra refusée ou indisponible : un état à nous, traduit, avec de quoi la
/// rouvrir, à la place du message anglais du paquet.
class BookScannerScreen extends ConsumerStatefulWidget {
  const BookScannerScreen({super.key});

  @override
  ConsumerState<BookScannerScreen> createState() => _BookScannerScreenState();
}

/// Durée de « Déjà dans votre collection » pour un code de la caméra : le
/// temps de lire, pas plus (la caméra en lit d'autres).
const _cameraOwnedNoticeDuration = Duration(seconds: 2);

/// Même message après une saisie : on vient de fermer le clavier, le regard
/// revient à peine sur l'écran.
const _typedOwnedNoticeDuration = Duration(seconds: 4);

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

  /// [context] : celui du thème sombre, que la feuille reprend.
  Future<void> _typeIsbn(BuildContext context) async {
    final isbn = await IsbnEntrySheet.show(context);
    if (isbn == null || !mounted) return;
    _handle(
      ref.read(burstScanProvider.notifier).scan(isbn, typed: true),
      typed: true,
    );
  }

  /// Vibre pour un ajout ; dit « déjà dans votre collection » sans vibrer.
  /// Un code relu ou illisible ne dit rien : la caméra le relit en boucle.
  /// [typed] : saisi à la main, le message reste plus longtemps.
  void _handle(ScanResult result, {bool typed = false}) {
    switch (result) {
      case (outcome: ScanOutcome.added, row: _):
        unawaited(HapticFeedback.lightImpact());
      case (outcome: ScanOutcome.alreadyOwned, row: final row?):
        // Un seul à la fois, bref : une pile de tomes possédés ne fait pas
        // défiler des messages en retard sur la caméra. Sans masquer la
        // snackbar en cours : ce peut être l'« Annuler » d'un retrait.
        // Une saisie, demandée, remplace notre message encore affiché (jamais
        // une autre snackbar).
        if (_ownedNotice case final shown?) {
          if (!typed) return;
          shown.close();
        }
        final notice = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: typed
                ? _typedOwnedNoticeDuration
                : _cameraOwnedNoticeDuration,
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
  /// classement, les autres sur leur feuille (classer, retirer). [context] :
  /// celui du thème sombre, que la feuille reprend.
  void _open(BuildContext context, BurstRow row) {
    if (row.status == BurstRowStatus.notFound) {
      final volume = ref.read(volumeByIdProvider(row.isbn)).value;
      if (volume != null) {
        unawaited(ClassifySheet.show(context, volume));
        return;
      }
    }
    unawaited(VolumeSheet.show(context, row.isbn));
  }

  /// Retire les tomes [rows] de la session, avec « Annuler » (un scan
  /// d'erreur, un doublon).
  void _remove(List<BurstRow> rows) => removeVolumesWithUndo(context, [
    for (final row in rows) row.isbn,
  ], message: burstRemovedText(context.l10n, rows));

  /// Ouvre la page de la série [seriesId] : la caméra s'arrête dessous (elle
  /// ajouterait des tomes sans qu'on le voie) et repart au retour.
  Future<void> _openSeries(BuildContext context, String seriesId) async {
    await controller.stop();
    if (!context.mounted) return;
    await context.push(AppRoutes.series(seriesId));
    if (mounted) await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    // Toujours la nuit, quel que soit le thème de l'app, comme une app photo :
    // la caméra est l'image, l'interface s'efface autour.
    return Theme(
      data: AppTheme.dark,
      child: Builder(builder: _buildDark),
    );
  }

  Widget _buildDark(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final rows = ref.watch(burstRowsProvider);
    // Grand texte ou écran court : le ticket prend la place, la caméra n'a
    // besoin que du code-barres.
    final compact =
        MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5 ||
        MediaQuery.sizeOf(context).height < 700;

    // Sans barre d'application : les icônes de la barre d'état restent
    // claires sur la caméra, quel que soit le thème de l'app.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PendingCompleter(
        child: Scaffold(
          backgroundColor: colorScheme.scrim,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: compact ? 38 : 55,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
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
                        overlayBuilder: (context, _) => _Overlay(
                          hint: l10n.scanHint,
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: compact ? 62 : 45,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.surface,
                    shape: const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.xl),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.lg,
                        AppSpacing.gutter,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: BurstTicket(
                              rows: rows,
                              onOpenSeries: (id) =>
                                  unawaited(_openSeries(context, id)),
                              onOpenRow: (row) => _open(context, row),
                              // Un tome scanné a son ISBN pour id.
                              onAddPrevious: (row) =>
                                  addPreviousWithUndo(context, row.isbn),
                              onRemove: _remove,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Côte à côte, ou l'un sous l'autre à 200 %.
                          OverflowBar(
                            alignment: MainAxisAlignment.spaceBetween,
                            overflowAlignment: OverflowBarAlignment.end,
                            overflowSpacing: AppSpacing.xs,
                            spacing: AppSpacing.sm,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => unawaited(_typeIsbn(context)),
                                icon: const Icon(Icons.keyboard_rounded),
                                label: Text(l10n.isbnEntryTitle),
                              ),
                              FilledButton(
                                onPressed: () => context.pop(),
                                child: Text(l10n.scanDone),
                              ),
                            ],
                          ),
                        ],
                      ),
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

/// Sur l'image de la caméra : retour et lampe sur des ronds de verre, le
/// viseur aux quatre coins, la consigne dans une pilule de verre.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.hint, required this.controller});

  final String hint;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              const GlassCircle(child: BackButton()),
              const Spacer(),
              _TorchButton(controller: controller),
            ],
          ),
          Expanded(
            // Une caméra réduite (grand texte, écran court) réduit le viseur.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: const Size(240, 144),
                    painter: _ViewfinderPainter(colorScheme.primaryFixed),
                  ),
                ),
              ),
            ),
          ),
          // Paysage et grand texte : la consigne cède la place au viseur.
          Flexible(child: _GlassPill(text: hint)),
        ],
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
        return GlassCircle(
          child: IconButton(
            onPressed: () => unawaited(controller.toggleTorch()),
            isSelected: on,
            tooltip: on ? l10n.torchOff : l10n.torchOn,
            icon: const Icon(Icons.flashlight_on_outlined),
            selectedIcon: const Icon(Icons.flashlight_on_rounded),
          ),
        );
      },
    );
  }
}

/// Les quatre coins du viseur, arrondis.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 28.0;
    const radius = 12.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    void corner(Offset origin, double sx, double sy) {
      final path = Path()
        ..moveTo(origin.dx, origin.dy + sy * arm)
        ..lineTo(origin.dx, origin.dy + sy * radius)
        ..quadraticBezierTo(
          origin.dx,
          origin.dy,
          origin.dx + sx * radius,
          origin.dy,
        )
        ..lineTo(origin.dx + sx * arm, origin.dy);
      canvas.drawPath(path, paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// La consigne, dans une pilule de verre sur la caméra.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: StadiumBorder()),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            // Le verre seul laisse passer un dos de livre blanc : posé sur un
            // voile, le texte reste lisible.
            color: Color.alphaBlend(
              colors.glass,
              Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
            ),
            shape: StadiumBorder(side: BorderSide(color: colors.glassBorder)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ),
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
