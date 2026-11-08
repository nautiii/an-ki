import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Livres : la feature `books`. Aujourd'hui, l'onglet du scanner de livres.
final booksModule = AppModule(
  id: 'books',
  alwaysOn: false,
  enabledByDefault: false,
  icon: Icons.qr_code_scanner_rounded,
  selectedIcon: Icons.qr_code_scanner_rounded,
  name: (l10n) => l10n.tabScanner,
  description: (l10n) => l10n.moduleBooksDescription,
  rootPath: AppRoutes.scanner,
  buildBranch: () => StatefulShellBranch(
    routes: [
      GoRoute(
        path: AppRoutes.scanner,
        builder: (_, _) => const BookScannerScreen(),
      ),
    ],
  ),
);
