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

/// Couleurs de marque AnKi (« lotus au clair de lune ») pour un thème donné.
///
/// Ajoutée à `ThemeData.extensions` par `AppTheme` ; lue via `context.ankiColors`.
@immutable
class AnKiColors extends ThemeExtension<AnKiColors> {
  const AnKiColors({
    required this.hero,
    required this.onHero,
    required this.celebration,
    required this.onCelebration,
    required this.onCelebrationAction,
    required this.petals,
    required this.blossom,
    required this.success,
    required this.moonlight,
    required this.glass,
    required this.glassBorder,
    required this.floatingShadow,
    required this.spine,
    required this.onSpine,
    required this.spineEdge,
    required this.spineAlt,
  });

  /// Rose lotus de l'icône : graine du thème.
  static const Color lotusSeed = Color(0xFFFFB6BF);

  /// Bleu nuage de l'icône : rôles tertiaires.
  static const Color cloudSeed = Color(0xFFC5DEFF);

  /// Rouge prune de l'icône : bout clair du dégradé du jour J.
  static const Color plumSeed = Color(0xFFFF1E32);

  /// Vermillon des erreurs : à 25° de teinte du framboise, une erreur ne se
  /// confond plus avec l'action principale (le rouge M3 n'en était qu'à 15°).
  static const Color errorSeed = Color(0xFFF4511E);

  /// Lotus des illustrations : célébration, « aujourd'hui ».
  static const Color blossomSeed = Color(0xFFF88898);

  /// Feuille des illustrations : succès, « souhaité ».
  static const Color mintSeed = Color(0xFF70D8B8);

  /// Lavande de la lune (la mascotte) : accents calmes, motif lunaire.
  static const Color moonSeed = Color(0xFFD0D0F8);

  /// Héros sombre : baie → bleu nuit. Les rôles du schéma sombre
  /// (`primaryContainer`, `tertiaryContainer`) contrastent moins avec le texte.
  static const Color _nightBerry = Color(0xFF7A1035);
  static const Color _nightBlue = Color(0xFF1E3F6E);

  /// Texte rose pâle sur les dégradés sombres.
  static const Color _blush = Color(0xFFFFE0E5);

  /// Jour J : framboise → rouge prune (clair), prune → grenat (sombre).
  static const Color _raspberry = Color(0xFFA8003D);

  /// `primary` vibrant de [plumSeed] en clair : assez foncé pour le texte
  /// blanc secondaire à 85 % (AA), calculé une seule fois.
  static final Color _plumRed = ColorScheme.fromSeed(
    seedColor: plumSeed,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  ).primary;
  static const Color _plum = Color(0xFF7A0030);
  static const Color _garnet = Color(0xFF9B1B30);

  /// Pétales : lotus profond et or des étamines (le lotus clair est [lotusSeed]).
  static const Color _deepLotus = Color(0xFFF98F9E);
  static const Color _stamenGold = Color(0xFFFFD849);

  /// Dérive les couleurs de marque du schéma de base : lotus et nuage au
  /// jour, baie et bleu nuit la nuit, jamais un aplat pastel éblouissant.
  factory AnKiColors.from(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    const top = Alignment.topLeft;
    const bottom = Alignment.bottomRight;
    final petalAlpha = isDark ? 0.75 : 0.9;
    return AnKiColors(
      // Clair : les rôles « fixed » (lotus → nuage) contrastent mieux avec
      // leur texte que les valeurs du prototype.
      hero: LinearGradient(
        begin: top,
        end: bottom,
        colors: isDark
            ? const [_nightBerry, _nightBlue]
            : [scheme.primaryFixedDim, scheme.tertiaryFixedDim],
      ),
      onHero: isDark ? _blush : scheme.onPrimaryFixed,
      celebration: LinearGradient(
        begin: top,
        end: bottom,
        colors: isDark ? const [_plum, _garnet] : [_raspberry, _plumRed],
      ),
      onCelebration: isDark ? _blush : Colors.white,
      // Le départ du dégradé, sur un bouton plein [onCelebration].
      onCelebrationAction: isDark ? _plum : _raspberry,
      // Lotus clair, lotus profond, or des étamines : visibles sur le dégradé
      // de fête, adoucis la nuit.
      petals: [
        for (final color in const [lotusSeed, _deepLotus, _stamenGold])
          color.withValues(alpha: petalAlpha),
      ],
      blossom: TonalColors.fromSeed(blossomSeed, scheme.brightness),
      success: TonalColors.fromSeed(mintSeed, scheme.brightness),
      moonlight: TonalColors.fromSeed(moonSeed, scheme.brightness),
      glass: scheme.surfaceContainer.withValues(alpha: isDark ? 0.65 : 0.78),
      glassBorder: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.6),
      // Ombre rosée, teintée par le lotus.
      floatingShadow: isDark
          ? const []
          : [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
      // Dos possédés du rayon : en clair, le lotus pâle se perdait sur la
      // toile (1,2:1) ; le lotus profond tient 6:1. La nuit, le conteneur
      // lotus garde sa douceur et un filet en dessine le bord.
      spine: isDark ? scheme.secondaryContainer : scheme.secondary,
      onSpine: isDark ? scheme.onSecondaryContainer : scheme.onSecondary,
      spineEdge: isDark ? scheme.outline : scheme.secondary,
      // Un dos sur deux un ton plus profond : des livres, pas un aplat.
      spineAlt: Color.lerp(
        isDark ? scheme.secondaryContainer : scheme.secondary,
        isDark ? scheme.onSecondaryContainer : scheme.onSecondary,
        0.08,
      )!,
    );
  }

  /// Dégradé du héros « prochain anniversaire » (signature S1).
  final LinearGradient hero;

  /// Texte et icônes sur [hero] ; texte secondaire à 85 % minimum.
  final Color onHero;

  /// Dégradé du jour J (framboise → rouge prune, prune → grenat la nuit).
  final LinearGradient celebration;
  final Color onCelebration;

  /// Texte et icône d'un bouton plein posé sur [celebration], dont le fond
  /// est [onCelebration] (« Souhaiter »).
  final Color onCelebrationAction;

  /// Teintes de la pluie de pétales (S4) sur [celebration].
  final List<Color> petals;
  final TonalColors blossom;
  final TonalColors success;
  final TonalColors moonlight;

  /// Fond de la barre de navigation flottante (verre dépoli).
  final Color glass;
  final Color glassBorder;

  /// Ombre des éléments flottants : teintée en clair, aucune en sombre.
  final List<BoxShadow> floatingShadow;

  /// Dos d'un tome possédé sur le rayon d'une série, son numéro et son bord
  /// (≥ 3:1 sur la surface : le bord dessine le livre la nuit).
  final Color spine;
  final Color onSpine;
  final Color spineEdge;

  /// Un dos sur deux, un ton plus profond que [spine] ; [onSpine] dessus.
  final Color spineAlt;

  @override
  AnKiColors copyWith({
    LinearGradient? hero,
    Color? onHero,
    LinearGradient? celebration,
    Color? onCelebration,
    Color? onCelebrationAction,
    List<Color>? petals,
    TonalColors? blossom,
    TonalColors? success,
    TonalColors? moonlight,
    Color? glass,
    Color? glassBorder,
    List<BoxShadow>? floatingShadow,
    Color? spine,
    Color? onSpine,
    Color? spineEdge,
    Color? spineAlt,
  }) {
    return AnKiColors(
      hero: hero ?? this.hero,
      onHero: onHero ?? this.onHero,
      celebration: celebration ?? this.celebration,
      onCelebration: onCelebration ?? this.onCelebration,
      onCelebrationAction: onCelebrationAction ?? this.onCelebrationAction,
      petals: petals ?? this.petals,
      blossom: blossom ?? this.blossom,
      success: success ?? this.success,
      moonlight: moonlight ?? this.moonlight,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      floatingShadow: floatingShadow ?? this.floatingShadow,
      spine: spine ?? this.spine,
      onSpine: onSpine ?? this.onSpine,
      spineEdge: spineEdge ?? this.spineEdge,
      spineAlt: spineAlt ?? this.spineAlt,
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
      onCelebrationAction: Color.lerp(
        onCelebrationAction,
        other.onCelebrationAction,
        t,
      )!,
      // Même nombre de teintes dans les deux thèmes.
      petals: [
        for (final (index, color) in petals.indexed)
          Color.lerp(color, other.petals[index], t)!,
      ],
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
      spine: Color.lerp(spine, other.spine, t)!,
      onSpine: Color.lerp(onSpine, other.onSpine, t)!,
      spineEdge: Color.lerp(spineEdge, other.spineEdge, t)!,
      spineAlt: Color.lerp(spineAlt, other.spineAlt, t)!,
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
