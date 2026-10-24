import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
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
      segments: [
        ButtonSegment(
          value: ThemePreference.system,
          icon: const Icon(Icons.brightness_auto_rounded),
          label: Text(l10n.themeSystem),
        ),
        ButtonSegment(
          value: ThemePreference.light,
          icon: const Icon(Icons.light_mode_rounded),
          label: Text(l10n.themeLight),
        ),
        ButtonSegment(
          value: ThemePreference.dark,
          icon: const Icon(Icons.dark_mode_rounded),
          label: Text(l10n.themeDark),
        ),
      ],
      // Écriture optimiste : un échec est signalé par l'écran des réglages.
      onChanged: (theme) => unawaited(
        ref.read(userProfileEditorProvider.notifier).setTheme(theme),
      ),
    );
  }
}

/// Une préférence à quelques valeurs : son titre, puis les segments sur toute
/// la largeur, pour tenir en grand texte.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.segments,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T selected;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // L'icône face au titre, pas au milieu des segments.
      titleAlignment: ListTileTitleAlignment.titleHeight,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: segments,
            selected: {selected},
            onSelectionChanged: (selection) {
              unawaited(HapticFeedback.selectionClick());
              onChanged(selection.single);
            },
          ),
        ),
      ),
    );
  }
}
