import 'dart:async';

import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Complète les tomes scannés hors ligne quand une page de Livres s'ouvre, et
/// au retour dans l'app tant qu'elle est visible : la file, c'est Firestore
/// (`ShelfEditor.completePending`). Sans paquet de connectivité : hors ligne,
/// la première recherche échoue et la passe s'arrête sans rien marquer.
///
/// Plusieurs pages ouvertes l'une sur l'autre ne lancent qu'une passe :
/// l'éditeur n'en mène qu'une à la fois.
class PendingCompleter extends ConsumerStatefulWidget {
  const PendingCompleter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PendingCompleter> createState() => _PendingCompleterState();
}

class _PendingCompleterState extends ConsumerState<PendingCompleter> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Garde l'éditeur (autoDispose) en vie pendant la passe.
    ref.listenManual(shelfEditorProvider, (_, _) {});
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // Un onglet caché (une autre branche affichée) ne compte pas.
        if (mounted && TickerMode.valuesOf(context).enabled) _complete();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _complete();
    });
  }

  void _complete() =>
      unawaited(ref.read(shelfEditorProvider.notifier).completePending());

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
