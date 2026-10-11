import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Les polices ne sont pas embarquées : on évite toute tentative réseau.
  // Réglé avant le premier accès à AppTheme, qui construit les styles.
  GoogleFonts.config.allowRuntimeFetching = false;

  // google_fonts journalise alors l'échec de chargement des polices : sans
  // intérêt ici, seuls les styles produits sont vérifiés.
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  tearDownAll(() => debugPrint = originalDebugPrint);

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
          expect(style?.fontFamily, startsWith('Outfit'));
          expect(style?.fontFamilyFallback, contains('Outfit'));
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
        expect(appBar.titleTextStyle?.fontFamily, startsWith('Outfit'));
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

      test('installs the brand colors for its brightness', () {
        final colors = theme.extension<AnKiColors>();

        expect(colors, isNotNull);
        expect(
          colors!.hero.colors,
          brightness == Brightness.dark
              ? [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ]
              : [theme.colorScheme.primary, theme.colorScheme.tertiary],
        );
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
