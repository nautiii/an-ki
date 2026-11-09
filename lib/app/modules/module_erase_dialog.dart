import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_data_eraser.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre la confirmation de l'effacement des données de [module].
Future<void> showModuleEraseDialog(BuildContext context, AppModule module) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ModuleEraseDialog(module: module),
    );

/// « Effacer les données Livres ? » : nomme l'objet et dit que c'est
/// définitif. Pendant l'effacement, il montre sa progression et se ferme
/// quand on veut (« Fermer », retour) : l'effacement continue, il peut
/// attendre le réseau. À la fin, il se ferme s'il est encore là, et une
/// snackbar dit l'issue : effacées, ou pourquoi elles ne l'ont pas été (hors
/// ligne, rien n'est effacé).
class _ModuleEraseDialog extends ConsumerWidget {
  const _ModuleEraseDialog({required this.module});

  final AppModule module;

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    // Lus d'abord : le dialogue peut être fermé avant la fin.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final name = module.name(l10n);
    final erased = await ref
        .read(moduleDataEraserProvider.notifier)
        .erase(module.id);
    // Seulement s'il est encore au-dessus : sinon `pop` fermerait l'écran
    // d'en dessous.
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
    if (erased) unawaited(HapticFeedback.lightImpact());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          erased ? l10n.moduleErased(name) : l10n.moduleEraseError(name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = module.name(l10n);
    // Regardé aussi pour garder le contrôleur en vie pendant l'effacement.
    final busy = ref.watch(moduleDataEraserProvider).isLoading;

    return AlertDialog(
      title: Text(l10n.moduleEraseTitle(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.moduleEraseConfirmation(name)),
            if (busy) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                semanticsLabel: l10n.moduleEraseInProgress,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          // Une fois lancé, l'effacement ne s'annule pas : on ferme.
          child: Text(busy ? l10n.close : l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: busy ? null : () => _erase(context, ref),
          child: Text(l10n.moduleErase),
        ),
      ],
    );
  }
}
