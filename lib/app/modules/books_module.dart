import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/books/providers/shelf_data_hooks.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:an_ki/features/books/screens/series_screen.dart';
import 'package:an_ki/features/books/screens/shelf_inbox_screen.dart';
import 'package:an_ki/features/books/screens/shelf_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Livres : la feature `books`, éteint par défaut. Son onglet est l'étagère ;
/// le scanner, une série et « À classer » sont des pages poussées au-dessus
/// des onglets (navigateur racine), sous `/books` pour que la redirection
/// des modules les reconnaisse.
final booksModule = AppModule(
  id: 'books',
  alwaysOn: false,
  enabledByDefault: false,
  icon: Icons.auto_stories_outlined,
  selectedIcon: Icons.auto_stories_rounded,
  name: (l10n) => l10n.moduleBooks,
  description: (l10n) => l10n.moduleBooksDescription,
  rootPath: AppRoutes.books,
  buildBranch: (rootNavigatorKey) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: AppRoutes.books,
        builder: (_, _) => const ShelfScreen(),
        // Segments de AppRoutes.booksScan, booksInbox et seriesPattern.
        routes: [
          // La caméra ne tourne que tant que cette page est ouverte.
          GoRoute(
            path: 'scan',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, _) => const BookScannerScreen(),
          ),
          GoRoute(
            path: 'inbox',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, _) => const ShelfInboxScreen(),
          ),
          GoRoute(
            path: 'series/:id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, state) =>
                SeriesScreen(seriesId: state.pathParameters['id']!),
          ),
        ],
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
