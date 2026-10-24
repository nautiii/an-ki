import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pseudo modifié sur place : « OK » au clavier ou la coche l'enregistrent,
/// sans bouton à part. Vide, il s'efface et l'accueil reprend le prénom.
class PseudoField extends ConsumerStatefulWidget {
  const PseudoField({super.key});

  @override
  ConsumerState<PseudoField> createState() => _PseudoFieldState();
}

class _PseudoFieldState extends ConsumerState<PseudoField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _saved);
    // Le pseudo enregistré change (profil chargé après coup, autre appareil) :
    // le champ le suit tant qu'on n'y a rien changé.
    ref.listenManual(
      userProfileProvider.select((user) => user.value?.pseudo ?? ''),
      (previous, next) {
        if (_controller.text.trim() == (previous ?? '')) {
          _controller.text = next;
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pseudo enregistré dans le profil, vide s'il n'y en a pas.
  String get _saved => ref.read(userProfileProvider).value?.pseudo ?? '';

  /// Écriture optimiste : un échec est signalé par l'écran des réglages.
  void _save() {
    final pseudo = _controller.text.trim();
    FocusScope.of(context).unfocus();
    if (pseudo == _saved) return;
    unawaited(
      ref.read(userProfileEditorProvider.notifier).updatePseudo(pseudo),
    );
    unawaited(HapticFeedback.lightImpact());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.pseudoSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saved =
        ref.watch(userProfileProvider.select((user) => user.value?.pseudo)) ??
        '';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: l10n.pseudo,
            helperText: l10n.pseudoHelper,
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            // La coche n'apparaît qu'avec un changement à enregistrer.
            suffixIcon: _controller.text.trim() == saved
                ? null
                : IconButton(
                    onPressed: _save,
                    tooltip: l10n.savePseudo,
                    icon: const Icon(Icons.check_rounded),
                  ),
          ),
        ),
      ),
    );
  }
}
