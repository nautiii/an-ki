import 'dart:ui' show ImageFilter;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Un rond de verre dépoli sous un bouton d'icône ([child] : `BackButton`,
/// `IconButton`, menu) posé sur une image : l'en-tête flouté d'une série.
/// Même verre que la barre de navigation flottante.
class GlassCircle extends StatelessWidget {
  const GlassCircle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.glass,
            shape: CircleBorder(side: BorderSide(color: colors.glassBorder)),
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
            child: child,
          ),
        ),
      ),
    );
  }
}
