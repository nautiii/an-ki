import 'package:flutter/material.dart';

/// Espacements AnKi : grille de base 4dp, mise en page sur 8dp.
///
/// Mise en page (marges, écarts entre blocs) : multiples de 8.
/// Intérieur d'un composant (icône ↔ libellé, padding de chip) : 4, 8 ou 12.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Marge latérale des écrans (« ma » : le calme a besoin d'air).
  static const double gutter = lg;
}

/// Rayons AnKi, à utiliser avec des formes « galet »
/// (`RoundedSuperellipseBorder`, `ClipRSuperellipse`).
abstract final class AppRadii {
  const AppRadii._();

  /// Badges, compte à rebours dans une tuile.
  static const double xs = 8;

  /// Cellules de calendrier, vignettes, infobulles.
  static const double sm = 12;

  /// Conteneurs internes, champs, cadres d'image.
  static const double md = 16;

  /// Cartes, tuiles de liste, héros, dialogues.
  static const double lg = 24;

  /// Haut des bottom sheets, barre de navigation flottante.
  static const double xl = 32;
}

/// Mouvement AnKi : vocabulaire produit sur les tokens Material 3.
abstract final class AppMotion {
  const AppMotion._();

  /// Appui, bascule, sélection.
  static const Duration tap = Durations.short4;

  /// Un élément entre (contenu de sheet, item, snackbar).
  static const Duration enter = Durations.medium2;

  /// Un élément sort.
  static const Duration exit = Durations.short4;

  /// Transition d'écran ou de conteneur.
  static const Duration page = Durations.long2;

  static const Curve standard = Easing.standard;
  static const Curve enterCurve = Easing.emphasizedDecelerate;
  static const Curve exitCurve = Easing.emphasizedAccelerate;
}

/// Respecte le réglage système « supprimer les animations ».
extension MotionContextX on BuildContext {
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Durée effective : zéro si l'utilisateur a coupé les animations.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
