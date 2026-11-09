import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/books/providers/shelf_data_hooks.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Livres : la feature `books`, éteint par défaut. Aujourd'hui, son onglet
/// est encore le scanner de livres.
final booksModule = AppModule(
  id: 'books',
  alwaysOn: false,
  enabledByDefault: false,
  icon: Icons.auto_stories_outlined,
  selectedIcon: Icons.auto_stories_rounded,
  name: (l10n) => l10n.moduleBooks,
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
  // L'étagère (séries, tomes) et les anciens livres : effacés avec le compte,
  // marqués comme invité avant la connexion, repris par le compte cible après.
  data: ModuleData(
    eraser: (ref) => ref.watch(shelfDataEraserProvider),
    guestTransfer: (ref) => ref.watch(shelfGuestTransferProvider),
  ),
);
