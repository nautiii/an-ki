import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const seedColor = Color(0xFF073165);

  static ThemeData light = _buildTheme(Brightness.light);
  static ThemeData dark = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _outfitTextTheme(ThemeData(brightness: brightness).textTheme)
          .copyWith(
            headlineLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            headlineMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            titleLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Applique la police Outfit à chacun des styles de [base].
  ///
  /// Équivalent exact de `GoogleFonts.outfitTextTheme` : depuis google_fonts 9,
  /// cette méthode attend le `TextTheme` du paquet `material_ui`, un type
  /// distinct de celui de `package:flutter/material.dart` utilisé par l'app.
  /// `GoogleFonts.outfit` ne manipule que des `TextStyle`, communs aux deux.
  static TextTheme _outfitTextTheme(TextTheme base) => TextTheme(
    displayLarge: GoogleFonts.outfit(textStyle: base.displayLarge),
    displayMedium: GoogleFonts.outfit(textStyle: base.displayMedium),
    displaySmall: GoogleFonts.outfit(textStyle: base.displaySmall),
    headlineLarge: GoogleFonts.outfit(textStyle: base.headlineLarge),
    headlineMedium: GoogleFonts.outfit(textStyle: base.headlineMedium),
    headlineSmall: GoogleFonts.outfit(textStyle: base.headlineSmall),
    titleLarge: GoogleFonts.outfit(textStyle: base.titleLarge),
    titleMedium: GoogleFonts.outfit(textStyle: base.titleMedium),
    titleSmall: GoogleFonts.outfit(textStyle: base.titleSmall),
    bodyLarge: GoogleFonts.outfit(textStyle: base.bodyLarge),
    bodyMedium: GoogleFonts.outfit(textStyle: base.bodyMedium),
    bodySmall: GoogleFonts.outfit(textStyle: base.bodySmall),
    labelLarge: GoogleFonts.outfit(textStyle: base.labelLarge),
    labelMedium: GoogleFonts.outfit(textStyle: base.labelMedium),
    labelSmall: GoogleFonts.outfit(textStyle: base.labelSmall),
  );
}
