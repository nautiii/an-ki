import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wish_message.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message de vœu d'une personne sur sa page : celui qu'enverra
/// « Souhaiter », le sien ou celui par défaut. Un toucher ouvre
/// [WishMessageSheet].
class WishMessageSection extends StatelessWidget {
  const WishMessageSection({super.key, required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final variant = theme.colorScheme.onSurfaceVariant;
    final custom = birthday.wishMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un en-tête de section, comme les autres titres de la page.
        Semantics(
          container: true,
          header: true,
          child: Text(
            l10n.wishMessageTitle,
            style: theme.textTheme.labelLarge?.copyWith(color: variant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          hint: l10n.wishMessageEdit,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => unawaited(WishMessageSheet.show(context, birthday)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            custom ?? l10n.wishMessage(birthday.name),
                            // Un aperçu : TalkBack lit le message entier.
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (custom == null)
                            Text(
                              l10n.wishMessageDefaultCaption,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: variant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ExcludeSemantics(
                      child: Icon(Icons.edit_rounded, color: variant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Personnalise le message de vœu : un champ prérempli (le message de la
/// personne, sinon celui par défaut), « Enregistrer » quand il a changé, et
/// « Rétablir le message par défaut » quand elle en a un à elle.
class WishMessageSheet extends ConsumerStatefulWidget {
  const WishMessageSheet({super.key, required this.birthday});

  final Birthday birthday;

  static Future<void> show(BuildContext context, Birthday birthday) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => WishMessageSheet(birthday: birthday),
      );

  @override
  ConsumerState<WishMessageSheet> createState() => _WishMessageSheetState();
}

class _WishMessageSheetState extends ConsumerState<WishMessageSheet> {
  late final String _default = context.l10n.wishMessage(widget.birthday.name);
  late final _message = TextEditingController(
    text: widget.birthday.wishMessage ?? _default,
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String? get _custom =>
      customWishMessage(_message.text, defaultMessage: _default);

  bool get _changed => _custom != widget.birthday.wishMessage;

  /// Enregistre [message] et ferme la feuille. Revenir au défaut efface un
  /// texte écrit à la main : « Annuler » le remet.
  void _save(String? message) {
    final birthdayId = widget.birthday.id;
    final previous = widget.birthday.wishMessage;
    final editor = ref.read(birthdayEditorProvider.notifier);
    unawaited(editor.setWishMessage(birthdayId, message));
    unawaited(HapticFeedback.lightImpact());
    if (message == null && previous != null) {
      final l10n = context.l10n;
      final accessible = MediaQuery.accessibleNavigationOf(context);
      // Lu par le conteneur : la feuille, et son ref, disparaissent.
      final container = ProviderScope.containerOf(context, listen: false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.wishMessageRestored),
            // Depuis Flutter 3.44, une snackbar avec action reste sinon
            // ouverte.
            persist: false,
            duration: accessible ? undoDelay * 2 : undoDelay,
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => unawaited(
                container
                    .read(birthdayEditorProvider.notifier)
                    .setWishMessage(birthdayId, previous),
              ),
            ),
          ),
        );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.wishMessageTitle,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 8,
            maxLength: wishMessageMaxLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.wishMessageField,
              helperText: l10n.wishMessageHelper,
              // Entière même à 200 % : coupée, elle ne se lit plus.
              helperMaxLines: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _changed ? () => _save(_custom) : null,
            child: Text(l10n.save),
          ),
          if (widget.birthday.wishMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.wishMessageReset),
              onPressed: () => _save(null),
            ),
          ],
        ],
      ),
    );
  }
}
