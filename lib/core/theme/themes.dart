import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B1C2C),
  );
}

// class AppTheme {
//
//   static const seedColor = Color(0xFF0B1C2C);
//
//   static ThemeData lightTheme = ThemeData(
//     useMaterial3: true,
//     colorScheme: ColorScheme.fromSeed(
//       seedColor: seedColor,
//       brightness: Brightness.light,
//     ),
//   );
//
//   static ThemeData darkTheme = ThemeData(
//     useMaterial3: true,
//     colorScheme: ColorScheme.fromSeed(
//       seedColor: seedColor,
//       brightness: Brightness.dark,
//     ),
//   );
//
// }
