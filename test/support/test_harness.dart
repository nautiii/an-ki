import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_providers.dart';

/// A harness to wrap widgets for testing with a standard [ProviderScope] and a
/// router-based [MaterialApp], like the app's: the widget (or [home]) above a
/// blank page, and [routes] (path → page) for the navigation it triggers.
class TestHarness extends StatefulWidget {
  final Widget child;
  final List<dynamic> overrides;
  final Widget? home;
  final Map<String, WidgetBuilder>? routes;

  const TestHarness({
    super.key,
    required this.child,
    this.overrides = const [],
    this.home,
    this.routes,
  });

  @override
  State<TestHarness> createState() => _TestHarnessState();
}

class _TestHarnessState extends State<TestHarness> {
  // Le widget s'affiche au-dessus d'une page vide : une feuille qui se ferme
  // (`Navigator.pop`) a une page où revenir, comme dans l'app.
  late final GoRouter _router = GoRouter(
    initialLocation: '/widget',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(
            path: 'widget',
            builder: (_, _) => Scaffold(body: widget.home ?? widget.child),
          ),
        ],
      ),
      for (final MapEntry(key: path, value: builder)
          in (widget.routes ?? const <String, WidgetBuilder>{}).entries)
        GoRoute(path: path, builder: (context, _) => builder(context)),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If overrides are provided, we assume the test knows what it's doing.
    // Otherwise, we use the defaults.
    final List<dynamic> finalOverrides = widget.overrides.isEmpty
        ? defaultTestOverrides
        : widget.overrides;

    return ProviderScope(
      // Pas de nouvelle tentative automatique : un provider en erreur s'affiche
      // en erreur tout de suite, sans minuteurs de retry en attente.
      retry: (_, _) => null,
      overrides: finalOverrides.map((e) => e as dynamic).toList().cast(),
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        routerConfig: _router,
      ),
    );
  }
}

extension WidgetTesterExt on WidgetTester {
  Future<void> pumpHarness(
    Widget widget, {
    List<dynamic> overrides = const [],
    Widget? home,
    Map<String, WidgetBuilder>? routes,
  }) async {
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await pumpWidget(
      TestHarness(
        overrides: overrides,
        home: home,
        routes: routes,
        child: widget,
      ),
    );
  }

  /// Contexte localisé (français, comme le harnais) pour tester une
  /// extension d'affichage — libellé, date — sans écran.
  Future<BuildContext> pumpLocalizedContext() async {
    late BuildContext captured;
    await pumpHarness(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    return captured;
  }
}
