import 'package:flutter/material.dart';

/// Paire tonale accessible (≥ 7:1 en clair comme en sombre) dérivée d'une graine.
///
/// `color`/`onColor` pour les pastilles et accents pleins,
/// `container`/`onContainer` pour les chips, badges et grandes surfaces.
@immutable
class TonalColors {
  const TonalColors({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });

  factory TonalColors.fromSeed(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return TonalColors(
      color: scheme.primary,
      onColor: scheme.onPrimary,
      container: scheme.primaryContainer,
      onContainer: scheme.onPrimaryContainer,
    );
  }

  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  static final Map<(Color, Brightness), TonalColors> _cache = {};

  /// Version mise en cache, pour les listes (avatars, catégories).
  static TonalColors of(Color seed, Brightness brightness) =>
      _cache[(seed, brightness)] ??= TonalColors.fromSeed(seed, brightness);

  static TonalColors lerp(TonalColors a, TonalColors b, double t) =>
      TonalColors(
        color: Color.lerp(a.color, b.color, t)!,
        onColor: Color.lerp(a.onColor, b.onColor, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// Couleurs de marque AnKi (« jardin au clair de lune ») pour un thème donné.
///
/// Ajoutée à `ThemeData.extensions` par `AppTheme` ; lue via `context.ankiColors`.
@immutable
class AnKiColors extends ThemeExtension<AnKiColors> {
  const AnKiColors({
    required this.hero,
    required this.onHero,
    required this.celebration,
    required this.onCelebration,
    required this.blossom,
    required this.success,
    required this.moonlight,
    required this.glass,
    required this.glassBorder,
    required this.floatingShadow,
  });

  /// Lotus des illustrations : célébration, « aujourd'hui ».
  static const Color blossomSeed = Color(0xFFF88898);

  /// Feuille des illustrations : succès, « souhaité ».
  static const Color mintSeed = Color(0xFF70D8B8);

  /// Lavande de la lune : accents calmes, motif lunaire.
  static const Color moonSeed = Color(0xFFD0D0F8);

  /// Dérive les couleurs de marque du schéma de base : le crépuscule (clair)
  /// devient un ciel de nuit (sombre), jamais un aplat pastel éblouissant.
  factory AnKiColors.from(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final blossom = TonalColors.fromSeed(blossomSeed, scheme.brightness);
    return AnKiColors(
      hero: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [scheme.primaryContainer, scheme.tertiaryContainer]
            : [scheme.primary, scheme.tertiary],
      ),
      onHero: isDark ? scheme.onPrimaryContainer : scheme.onPrimary,
      celebration: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [scheme.primaryContainer, blossom.container]
            : [scheme.primary, blossom.color],
      ),
      onCelebration: isDark ? blossom.onContainer : blossom.onColor,
      blossom: blossom,
      success: TonalColors.fromSeed(mintSeed, scheme.brightness),
      moonlight: TonalColors.fromSeed(moonSeed, scheme.brightness),
      glass: scheme.surfaceContainer.withValues(alpha: isDark ? 0.65 : 0.78),
      glassBorder: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.6),
      floatingShadow: isDark
          ? const []
          : [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  /// Dégradé du héros « prochain anniversaire » (signature S1).
  final LinearGradient hero;

  /// Texte et icônes sur [hero] ; texte secondaire à 85 % minimum.
  final Color onHero;

  /// Dégradé du jour J (nuit → lotus).
  final LinearGradient celebration;
  final Color onCelebration;
  final TonalColors blossom;
  final TonalColors success;
  final TonalColors moonlight;

  /// Fond de la barre de navigation flottante (verre dépoli).
  final Color glass;
  final Color glassBorder;

  /// Ombre des éléments flottants : teintée en clair, aucune en sombre.
  final List<BoxShadow> floatingShadow;

  @override
  AnKiColors copyWith({
    LinearGradient? hero,
    Color? onHero,
    LinearGradient? celebration,
    Color? onCelebration,
    TonalColors? blossom,
    TonalColors? success,
    TonalColors? moonlight,
    Color? glass,
    Color? glassBorder,
    List<BoxShadow>? floatingShadow,
  }) {
    return AnKiColors(
      hero: hero ?? this.hero,
      onHero: onHero ?? this.onHero,
      celebration: celebration ?? this.celebration,
      onCelebration: onCelebration ?? this.onCelebration,
      blossom: blossom ?? this.blossom,
      success: success ?? this.success,
      moonlight: moonlight ?? this.moonlight,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  AnKiColors lerp(AnKiColors? other, double t) {
    if (other == null) return this;
    return AnKiColors(
      hero: LinearGradient.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      celebration: LinearGradient.lerp(celebration, other.celebration, t)!,
      onCelebration: Color.lerp(onCelebration, other.onCelebration, t)!,
      blossom: TonalColors.lerp(blossom, other.blossom, t),
      success: TonalColors.lerp(success, other.success, t),
      moonlight: TonalColors.lerp(moonlight, other.moonlight, t),
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      floatingShadow: BoxShadow.lerpList(
        floatingShadow,
        other.floatingShadow,
        t,
      )!,
    );
  }
}

extension AnKiColorsContextX on BuildContext {
  /// Couleurs de marque du thème courant.
  ///
  /// Repli calculé depuis le ColorScheme si l'extension est absente
  /// (ex. harnais de test sans AppTheme) : un widget ne plante jamais.
  AnKiColors get ankiColors {
    final theme = Theme.of(this);
    return theme.extension<AnKiColors>() ?? AnKiColors.from(theme.colorScheme);
  }
}
