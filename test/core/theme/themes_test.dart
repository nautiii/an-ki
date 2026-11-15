import 'dart:convert';
import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<TextStyle?> _allStyles(TextTheme t) => [
  t.displayLarge,
  t.displayMedium,
  t.displaySmall,
  t.headlineLarge,
  t.headlineMedium,
  t.headlineSmall,
  t.titleLarge,
  t.titleMedium,
  t.titleSmall,
  t.bodyLarge,
  t.bodyMedium,
  t.bodySmall,
  t.labelLarge,
  t.labelMedium,
  t.labelSmall,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles every Outfit weight the theme uses', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<Object?>;
    final outfit = manifest.cast<Map<String, Object?>>().singleWhere(
      (family) => family['family'] == 'Outfit',
    );
    final weights = {
      for (final font
          in (outfit['fonts']! as List<Object?>).cast<Map<String, Object?>>())
        font['asset']! as String: (font['weight'] as int?) ?? 400,
    };

    expect(weights, {
      'lib/assets/fonts/Outfit-Regular.ttf': 400,
      'lib/assets/fonts/Outfit-Medium.ttf': 500,
      'lib/assets/fonts/Outfit-SemiBold.ttf': 600,
      'lib/assets/fonts/Outfit-Bold.ttf': 700,
      'lib/assets/fonts/Outfit-ExtraBold.ttf': 800,
    });
  });

  test('paints lotus by day, plum night by night, from the icon', () {
    final day = AppTheme.light.colorScheme;
    final night = AppTheme.dark.colorScheme;

    expect(AppTheme.seedColor, AnKiColors.lotusSeed);
    expect(day.primary, const Color(0xFFBD0046));
    expect(day.primaryContainer, const Color(0xFFFFD9DD));
    expect(day.tertiary, const Color(0xFF35618E));
    expect(day.tertiaryContainer, const Color(0xFFD1E4FF));
    expect(day.surface, const Color(0xFFFFF8F7));
    expect(day.surfaceContainerLow, const Color(0xFFFFF0F1));
    expect(day.surfaceContainer, const Color(0xFFFFE9EA));
    expect(day.surfaceContainerHigh, const Color(0xFFFDE2E4));
    expect(night.primary, const Color(0xFFFFB2BC));
    expect(night.primaryContainer, const Color(0xFF910034));
    expect(night.tertiaryContainer, const Color(0xFF184974));
    expect(night.surface, const Color(0xFF1D1011));
    expect(night.surfaceContainerLow, const Color(0xFF261819));
    // Lotus tonal en secondaire : boutons tonals et indicateur restent roses
    // la nuit, jamais bruns ; le nuage en tertiaire.
    expect(night.secondaryContainer, const Color(0xFF72333E));
    expect(night.onSecondaryContainer, const Color(0xFFFFD9DD));
    expect(night.tertiary, const Color(0xFF9FCAFD));
  });

  for (final (label, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    test('takes secondary from the tonal lotus and tertiary from the cloud '
        '($label)', () {
      final scheme =
          (brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
              .colorScheme;
      final lotus = ColorScheme.fromSeed(
        seedColor: AnKiColors.lotusSeed,
        brightness: brightness,
      );
      final cloud = ColorScheme.fromSeed(
        seedColor: AnKiColors.cloudSeed,
        brightness: brightness,
      );

      expect(scheme.secondary, lotus.primary);
      expect(scheme.onSecondary, lotus.onPrimary);
      expect(scheme.secondaryContainer, lotus.primaryContainer);
      expect(scheme.onSecondaryContainer, lotus.onPrimaryContainer);
      expect(scheme.secondaryFixedDim, lotus.primaryFixedDim);
      expect(scheme.tertiary, cloud.primary);
      expect(scheme.onTertiary, cloud.onPrimary);
      expect(scheme.tertiaryContainer, cloud.primaryContainer);
      expect(scheme.onTertiaryContainer, cloud.onPrimaryContainer);
      expect(scheme.tertiaryFixedDim, cloud.primaryFixedDim);
      expect(scheme.onTertiaryFixed, cloud.onPrimaryFixed);
    });
  }

  for (final (label, theme, brightness) in [
    ('light', AppTheme.light, Brightness.light),
    ('dark', AppTheme.dark, Brightness.dark),
  ]) {
    group('AppTheme.$label', () {
      test('uses the matching brightness and Material 3', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, brightness);
      });

      test('applies Outfit to every text style', () {
        for (final style in _allStyles(theme.textTheme)) {
          expect(style?.fontFamily, 'Outfit');
        }
        for (final style in _allStyles(theme.primaryTextTheme)) {
          expect(style?.fontFamily, 'Outfit');
        }
      });

      test('keeps the base typography sizes', () {
        final base = ThemeData(brightness: brightness).textTheme;

        expect(theme.textTheme.bodyMedium?.fontSize, base.bodyMedium?.fontSize);
        expect(theme.textTheme.labelLarge?.fontSize, base.labelLarge?.fontSize);
      });

      test('emphasizes headlines and large titles', () {
        final onSurface = theme.colorScheme.onSurface;

        expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.bold);
        expect(theme.textTheme.headlineLarge?.color, onSurface);
        expect(theme.textTheme.headlineMedium?.fontWeight, FontWeight.bold);
        expect(theme.textTheme.headlineMedium?.color, onSurface);
        expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
        expect(theme.textTheme.titleLarge?.color, onSurface);
      });

      test('styles a transparent, centered app bar', () {
        final appBar = theme.appBarTheme;

        expect(appBar.backgroundColor, Colors.transparent);
        expect(appBar.elevation, 0);
        expect(appBar.scrolledUnderElevation, 0);
        expect(appBar.centerTitle, isTrue);
        expect(appBar.titleTextStyle?.fontFamily, 'Outfit');
        expect(appBar.titleTextStyle?.fontSize, 20);
        expect(appBar.titleTextStyle?.fontWeight, FontWeight.bold);
        expect(appBar.titleTextStyle?.color, theme.colorScheme.onSurface);
      });

      test('keeps status bar icons readable on the theme background', () {
        expect(
          theme.appBarTheme.systemOverlayStyle,
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
      });

      test('rings fields in error with the error color', () {
        final input = theme.inputDecorationTheme;
        final shape = BorderRadius.circular(AppRadii.md);

        expect(
          input.errorBorder,
          OutlineInputBorder(
            borderRadius: shape,
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
        );
        expect(
          input.focusedErrorBorder,
          OutlineInputBorder(
            borderRadius: shape,
            borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
          ),
        );
      });

      test('installs the brand colors for its brightness', () {
        final colors = theme.extension<AnKiColors>();

        expect(colors, isNotNull);
        expect(
          colors!.hero.colors.first,
          brightness == Brightness.dark
              ? const Color(0xFF7A1035)
              : theme.colorScheme.primaryFixedDim,
        );
        expect(colors.petals, hasLength(3));
      });

      test('keeps the undo action of a snackbar AA on its background', () {
        // L'action « Annuler » des snackbars reste celle de Material
        // (`inversePrimary`) sur `inverseSurface` : on fixe qu'elle se lit.
        expect(theme.snackBarTheme.actionTextColor, isNull);
        final scheme = theme.colorScheme;
        final action = scheme.inversePrimary.computeLuminance();
        final back = scheme.inverseSurface.computeLuminance();
        final ratio =
            (math.max(action, back) + 0.05) / (math.min(action, back) + 0.05);

        expect(ratio, greaterThanOrEqualTo(4.5));
      });

      test('shapes the components with the design tokens', () {
        final filled = theme.filledButtonTheme.style!;
        final states = <WidgetState>{};

        expect(filled.minimumSize?.resolve(states), const Size(64, 56));
        expect(filled.shape?.resolve(states), const StadiumBorder());
        expect(
          theme.outlinedButtonTheme.style!.side?.resolve(states)?.color,
          theme.colorScheme.outline,
        );
        expect(
          theme.textButtonTheme.style!.minimumSize?.resolve(states),
          const Size(48, 48),
        );
        expect(theme.cardTheme.elevation, 0);
        expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
        expect(
          theme.bottomSheetTheme.backgroundColor,
          theme.colorScheme.surfaceContainerLow,
        );
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.chipTheme.shape, const StadiumBorder());
        expect(
          theme.segmentedButtonTheme.style!.minimumSize?.resolve(states),
          const Size(48, 48),
        );
        expect(theme.listTileTheme.minVerticalPadding, AppSpacing.sm);
      });
    });
  }
}
