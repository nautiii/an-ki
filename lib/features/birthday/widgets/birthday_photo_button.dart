import 'dart:typed_data';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Avatar de la personne, ses initiales suivant la saisie ; le toucher
/// choisit une photo.
class BirthdayPhotoButton extends StatelessWidget {
  const BirthdayPhotoButton({
    super.key,
    required this.name,
    required this.picture,
    required this.onTap,
    this.radius = 28,
  });

  /// Rayon de l'avatar.
  final double radius;

  final String name;
  final Uint8List? picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final picture = this.picture;

    return Semantics(
      button: true,
      label: context.l10n.choosePhoto,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        children: [
          AnKiAvatar(
            name: name,
            image: picture != null ? MemoryImage(picture) : null,
            radius: radius,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surfaceContainerLow,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          // Au-dessus de l'avatar, pour que l'onde du toucher reste visible.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}
