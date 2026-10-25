import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teintes proposées pour un groupe, sur une ligne qui défile : un choix
/// unique, lu par TalkBack sous le nom de chaque couleur.
class TonePicker extends StatelessWidget {
  const TonePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tone in LabelTones.pickable)
            _ToneDot(
              tone: tone,
              selected: tone == selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(tone);
              },
            ),
        ],
      ),
    );
  }
}

/// Une pastille de teinte, cochée quand elle est choisie : la coche, pas la
/// seule couleur, dit le choix.
class _ToneDot extends StatelessWidget {
  const _ToneDot({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final int tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = LabelTones.of(tone, Theme.of(context).brightness);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: _toneName(context, tone),
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AppSpacing.lg,
        child: SizedBox.square(
          dimension: AppSpacing.xxl,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.color,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: AppSpacing.xl,
                child: selected
                    ? Icon(Icons.check_rounded, size: 20, color: colors.onColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nom d'une teinte de `LabelTones.pickable`, pour TalkBack.
String _toneName(BuildContext context, int tone) {
  final l10n = context.l10n;
  return switch (tone) {
    0 => l10n.toneBlue,
    1 => l10n.toneGreen,
    2 => l10n.toneOrange,
    4 => l10n.toneViolet,
    5 => l10n.toneCyan,
    10 => l10n.tonePink,
    7 => l10n.toneAmber,
    9 => l10n.toneTeal,
    _ => l10n.groupTone,
  };
}
