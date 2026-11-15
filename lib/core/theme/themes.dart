import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const seedColor = AnKiColors.lotusSeed;

  /// Famille embarquée (lib/assets/fonts, licence OFL) : vraies graisses de
  /// 400 à 800, rendu identique hors ligne.
  static const fontFamily = 'Outfit';

  static ThemeData light = _buildTheme(Brightness.light);
  static ThemeData dark = _buildTheme(Brightness.dark);

  /// Lotus vif (variante `vibrant`) ; les rôles secondaires reprennent le
  /// lotus en `tonalSpot` (sinon les boutons tonals et l'indicateur de la
  /// barre virent au brun en sombre), les tertiaires le bleu nuage de l'icône.
  static ColorScheme _colorScheme(Brightness brightness) {
    final lotus = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final cloud = ColorScheme.fromSeed(
      seedColor: AnKiColors.cloudSeed,
      brightness: brightness,
    );
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    ).copyWith(
      secondary: lotus.primary,
      onSecondary: lotus.onPrimary,
      secondaryContainer: lotus.primaryContainer,
      onSecondaryContainer: lotus.onPrimaryContainer,
      secondaryFixed: lotus.primaryFixed,
      secondaryFixedDim: lotus.primaryFixedDim,
      onSecondaryFixed: lotus.onPrimaryFixed,
      onSecondaryFixedVariant: lotus.onPrimaryFixedVariant,
      tertiary: cloud.primary,
      onTertiary: cloud.onPrimary,
      tertiaryContainer: cloud.primaryContainer,
      onTertiaryContainer: cloud.onPrimaryContainer,
      tertiaryFixed: cloud.primaryFixed,
      tertiaryFixedDim: cloud.primaryFixedDim,
      onTertiaryFixed: cloud.onPrimaryFixed,
      onTertiaryFixedVariant: cloud.onPrimaryFixedVariant,
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = _colorScheme(brightness);
    final base = ThemeData(
      brightness: brightness,
      fontFamily: fontFamily,
    ).textTheme;
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
    // Forme « galet » (superellipse) des cartes et des dialogues.
    const pebble = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      extensions: [AnKiColors.from(colorScheme)],
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // Icônes de la barre d'état lisibles sur le fond du thème (edge-to-edge).
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: buttonPadding,
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: pebble,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        // L'erreur se lit aussi au contour, pas seulement au texte rouge.
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      dialogTheme: const DialogThemeData(shape: pebble),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
