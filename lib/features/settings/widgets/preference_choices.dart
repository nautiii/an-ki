import 'dart:async';
import 'dart:math' as math;

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thème de l'app : celui du téléphone, clair ou sombre, appliqué dès le
/// toucher.
class ThemeChoice extends ConsumerWidget {
  const ThemeChoice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme =
        ref.watch(userProfileProvider.select((user) => user.value?.theme)) ??
        ThemePreference.system;

    return _ChoiceTile<ThemePreference>(
      icon: Icons.contrast_rounded,
      title: l10n.theme,
      selected: theme,
      options: [
        (ThemePreference.system, l10n.themeSystem),
        (ThemePreference.light, l10n.themeLight),
        (ThemePreference.dark, l10n.themeDark),
      ],
      // Écriture optimiste : un échec est signalé par l'écran des réglages.
      onChanged: (theme) => unawaited(
        ref.read(userProfileEditorProvider.notifier).setTheme(theme),
      ),
    );
  }
}

/// Langue de l'app, chacune écrite dans sa propre langue ; appliquée dès le
/// toucher.
class LanguageChoice extends ConsumerWidget {
  const LanguageChoice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return _ChoiceTile<String>(
      icon: Icons.language_rounded,
      title: l10n.language,
      selected: ref.watch(localeProvider).languageCode,
      options: [('fr', l10n.languageFrench), ('en', l10n.languageEnglish)],
      onChanged: (languageCode) => unawaited(
        ref.read(userProfileEditorProvider.notifier).setLocale(languageCode),
      ),
    );
  }
}

/// Une préférence à quelques valeurs : son titre, puis les segments sur toute
/// la largeur. Empilés quand un libellé ne tient plus sur une ligne (grand
/// texte, petit écran), plutôt que coupés.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Vrai si chaque segment, d'une largeur égale, garde son libellé entier.
  bool _fitsInRow(BuildContext context, double width) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final (_, label) in options) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    // Marges intérieures d'un segment et sa bordure, de chaque côté.
    const chrome = 2 * (AppSpacing.sm + 1);
    return (widest + chrome) * options.length <= width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => SegmentedButton<T>(
              direction: _fitsInRow(context, constraints.maxWidth)
                  ? Axis.horizontal
                  : Axis.vertical,
              showSelectedIcon: false,
              segments: [
                for (final (value, label) in options)
                  ButtonSegment(value: value, label: Text(label)),
              ],
              selected: {selected},
              onSelectionChanged: (selection) {
                unawaited(HapticFeedback.selectionClick());
                onChanged(selection.single);
              },
            ),
          ),
        ],
      ),
    );
  }
}
